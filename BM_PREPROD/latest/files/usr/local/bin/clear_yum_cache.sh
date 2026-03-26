#!/bin/bash
# Clean up of yum cache directory 
# Zayde James 27 Nov 2017
find /var/cache/yum/  -mtime +10 -exec rm -rf {} \;

