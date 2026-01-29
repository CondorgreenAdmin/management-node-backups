#/bin/bash

# Make sure to run from correct directory
cd ~/automation/dataloads

# Fetch VASES from Siebel
./DDE-SIEBEL-VAS.sh

# Fetch VASES from Eppix
./DDE-EPX-VAS.sh

# Merge them things
if [ $? -eq 0]; then
	./scripts/load-mysql-enr-active-vases.sh
fi
