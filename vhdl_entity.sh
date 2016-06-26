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
#line_entity_start=$
#cat $workfile
#grep -o '^[^--]*' $workfile
sed -ie 's/--.*$//' $workfile # remove all comments

line_entity_start="$(awk '/entity/{print NR; exit}' $workfile)" 
sed -i "1,$((line_entity_start - 1))"d $workfile  
line_entity_end="$(awk '/end/{print NR; exit}' $workfile)" 
sed -i "$line_entity_end,$"d $workfile  

# 3 TURN DECLARATION INTO INSTANTIATION ---------------------------------------------------

line_generic="$(awk '/generic/{print NR; exit}' $workfile)" 
sed -i "${line_generic}s/generic/generic map /" $workfile
sed -i "/generic map/s/(/(\n/" $workfile
line_port="$(awk '/port/{print NR; exit}' $workfile)" 
sed -i "${line_port}s/port/port map /" $workfile
sed -i "/port map/s/(/(\n/" $workfile

# remove all unnecessary white space 
sed -ie '/^$/d' $workfile      
sed -i 's/\t/ /g' $workfile # remove all indenting
sed -i 's/[ ][ ][ ]*/ /g' $workfile # replace multiple spaces with single spaces
sed -i '/^ /s/^ //' $workfile # remove spaces at start of lines
sed -i '/ $/s/; /;/' $workfile # remove spaces at end of lines

# change to instantiation syntax
sed -i 's/));/)\n);/' $workfile 
sed -i 's/:/\t=> # --/' $workfile 
sed -i "/;$/s/#/,/" $workfile # in lines finishing with ';' replace # with , 
sed -i "s/#/ /" $workfile # in remaining line replace '#' with ' ' 
sed -i '/=>/s/^/\t/' $workfile #replace indents for ports and generics

# Remove all occurrences of ';' except the last one.
sed -i '$!s/;//' $workfile 

# Remove last occurrence of ',' in port map and generic map
#sed -n "${line_generic, line_port}p" temp_sed_file 
#cat temp_sed_file

#last_comma="$(grep -n , $workfile | tail -1)"
#last_comma_line=$(echo $last_comma | cut -f1 -d":")
#sed -i "${last_comma_line}s/,/ /" $workfile

# Replace entity declaration line with entity instantiation line 
sed -i "1s/entity /i_$file_name : entity work./" $workfile
sed -i "1s/is//" $workfile

# 4 FINISH ------------------------------------------------------------------------------

cat $workfile
rm $workfile
