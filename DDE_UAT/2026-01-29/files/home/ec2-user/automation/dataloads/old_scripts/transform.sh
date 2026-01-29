#!/bin/sh

#cat extract_vpk_package.dat | awk '{gsub(/[^\40-\176]/, ""); print}' > cleaned_vpk.csv



#cat extract_vpk_package.dat |  perl -pe 's/[\xA0][^\x20-\x7E]\x0A//g' | awk -F "|" '
cat extract_vpk_package.dat |  gawk -F "|" '
function clean_string(str) {
    gsub(/[^[:print:]]/, " ", str)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", str)
    return str
}
{
   #Clean each field 
   $1 = "\"" clean_string($1) "\""
   $2 = "\"" clean_string($2) "\""
   $3 = "\"" clean_string($3) "\""
   $4 = "\"" clean_string($4) "\""
   print $1"|"$2"|"$3"|"$4
}' > cleaned_vpk.csv 
