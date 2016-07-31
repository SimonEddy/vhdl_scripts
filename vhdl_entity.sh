#!/bin/bash

# This script takes the name of a vhdl file as an argument,
# it finds the first entity declaration and converts that to an entity instantiation,
# it then prints out the contents of the entity instantiation.

# No 2nd arg; will create a 'relaxed' instantiation.
#   All arguments on new lines, with their type present in comments following

# 2nd arg = 'c'; will create a 'Condensed' inst.
#   All generic args share same line, all port args share same line. No comments.

# 2nd arg = 'g'; will 'Guess' the signal name to match each port.  

# 1.    PRE_CHECKS
# 1.1   Receive path_and_file_name as argument
# 1.2   Split path_and_file_name into path, file and extension
# 1.3   Check that it is a .vhd file.
# 1.4   Check that it contains key words: entity & is on the same line

# 2.    PULL OUT THE ENTITY DECLARATION
# 2.1   Copy the file into a working directory and give it name: file_name.entity
# 2.1   Remove all comments
# 2.2   Remove white_lines
# 2.3   Remove everything before the word entity
# 2.4   Pull out the word following entity and assign it to var entity_name
# 2.4   Remove everything after and (including) the line containing: end entity_name;

# 3     TURN ENTITY DECLARATION INTO INSTANTIATION
# 3.1   Place new_line after the words: generic and port
# 3.2   Put the word: 'map' after generic and port 
# 3.3   Place the string "=> , --" before each instance of the character ':'
# 3.4   Remove the last instance of the comma
# 3.5   Change "entity entity_name is" into "i_entity_name : entity work.entity_name"

# 4     FINISH
# 4.1   Print out the contents of the created file 
# 4.2   Delete the created file

#------------------------------------------------------------------------------------------

# 1 PREPARATION --------------------------------------------------------------------------
path_and_file_name="$1"
path=$(dirname "$path_and_file_name")
file_extn=$(basename "$path_and_file_name") 
file_name="${file_extn%.*}"
extension="${file_extn##*.}"

if [ "$extension" != 'vhd' ]; then
    echo "File is not vhdl" 
    return
fi

# check if 'entity' and 'is' are present on the same line
if ! grep -i entity "$path_and_file_name" | grep -1iq is ; then
    echo "vhdl file does not contain an entity declaration."
    return
fi

# 2 PULL OUT THE ENTITY DECLARATION -------------------------------------------------------

workfile=$"./$file_name.entity"
cp "$path_and_file_name" $workfile  
sed -i 's/--.*$//' $workfile # remove all comments

line_entity_start="$(awk '/\<entity\>/{print NR; exit}' $workfile)" 
sed -i "1,$((line_entity_start - 1))"d $workfile  
line_entity_end="$(awk '/\<end\>/{print NR; exit}' $workfile)" 
sed -i "$line_entity_end,$"d $workfile #delete lines after end  

# 3 TURN DECLARATION INTO INSTANTIATION ---------------------------------------------------

# Replace entity declaration line with entity instantiation line 
sed -i "1s/entity//" $workfile
sed -i "1s/is//" $workfile
sed -i "1s/ //g" $workfile
entity_name="$(sed -n 1p $workfile)"
sed -i "1s/$entity_name/i_$entity_name : entity work.$entity_name/" $workfile
sed -n '1p' $workfile 

# remove all unnecessary white space 
sed -i '/^$/d' $workfile # remove blank line     
sed -i 's/\t/ /g' $workfile # remove all indenting
sed -i 's/  */ /g' $workfile # replace multiple spaces with single spaces
sed -i '/^ /s/^ //' $workfile # remove spaces at start of lines
sed -i '/ $/s/; /;/' $workfile # remove spaces at end of lines

line_generic="$(awk '/\<generic\>/{print NR; exit}' $workfile)" 
sed -i "${line_generic}s/generic/generic map /" $workfile

line_port="$(awk '/port/{print NR; exit}' $workfile)" 
sed -i "${line_port}s/port/port map /" $workfile

fix_syntax()
{
    # change to instantiation syntax
    sed -i "1s/(/(\n/" $1
    sed -i '$s/);/\n);/' $1 
    sed -i '/^$/d' $1 # remove blank line if the above created one.     
    sed -i 's/,/\t=> ,\n/' $1
    sed -i 's/:/\t=> # --/' $1 
    sed -i "/;$/s/#/,/" $1 # in lines finishing with ';' replace # with , 
    sed -i "s/#/ /" $1 # in remaining line replace '#' with ' ' 
    sed -i 's/;//' $1 #Remove all occurrences of ';' 
    
    sed -i 's/^ //g' $1 # remove spaces at start of lines
    sed -i '/=>/s/^/\t/' $1 #replace indents for ports and generics
}

mapfile=$"./mapfile.entity"
total_lines=$(wc -l < "$workfile")

if [ -n "$line_generic" ] 
then
    #pull out generic declaration and put it in mapfile
    cat $workfile | tail $((line_generic - total_lines - 1)) | head $((line_generic - line_port)) > $mapfile
    #sed -n "${line_generic, line_port}p" temp_sed_file 
    fix_syntax $mapfile
    cat $mapfile
fi

#pull out port declaration and put it in mapfile
cat $workfile | tail $((line_port - total_lines - 1)) > $mapfile
fix_syntax $mapfile
sed -i '$s/)/);/' $mapfile  #replace the last ';' in the port map
cat $mapfile

# 4 IMPROVEMENTS -----------------------------------------------------------------------
    # Make sure tabs all align

# 4 FINISH ------------------------------------------------------------------------------
rm $mapfile
rm $workfile
