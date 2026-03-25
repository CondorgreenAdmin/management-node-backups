#!/bin/bash

cat extract_vpk_package.dat |  awk -F "|" '
function clean_string(str) {
    gsub(/^[[:space:][:cntrl:]]+|[[:space:][:cntrl:]]+$/, "", str)
    return str
}
{
   #Clean each field 
    $1 = clean_string($1)
    $2 = clean_string($2)
    $3 = clean_string($3)
    $4 = clean_string($4)
    print $1"|"$2"|"$3"|"$4
}'  
