#!/bin/bash

# which file to save the data
filename=""
if [[ $2 -eq "1" ]]; then
	filename="software_versioning"
fi

if [[ $2 -eq "2" ]]; then 
	filename="proc_versioning"
fi

filename="${filename}_$(date +%m_%Y).txt"
# save file data to individual backup files 
while IFS= read -r line; do 
	if [[ -n "$line" ]]; then
		echo "$(date +%Y-%m-%d) $line" >> ~/versioning/scripts/${filename}
	fi
done < $1
