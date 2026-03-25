#!/bin/bash
#
cd ~/scripts
./DDE-UX-FUNCTIONAL_USER.sh > /tmp/DDE-UX-FUNCTIONAL_USER.log
./DDE-DB-FUNCTIONAL_USER.sh > /tmp/DDE-DB-FUNCTIONAL_USER.log

sudo cp /tmp/DDE-*-FUNCTIONAL_USER.log /home/csgmon/
sudo chown csgmon:csgmon /home/csgmon/DDE-DB-FUNCTIONAL_USER.log
sudo chown csgmon:csgmon /home/csgmon/DDE-UX-FUNCTIONAL_USER.log

