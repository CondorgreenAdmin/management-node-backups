#!/bin/bash

# Replace 'your_alias' with the desired email alias
ALIAS="arnulf.hanauer@vcontractor.co.za"

/usr/sbin/sendmail -t -i -f "$ALIAS"

