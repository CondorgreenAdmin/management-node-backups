#!/bin/bash
#
OUTPUT_FILE=/tmp/Bonding_Setup.txt
#
echo "Current Bonding configuration " > $OUTPUT_FILE
echo "----------------------------- " >> $OUTPUT_FILE
egrep -i '^slave\ Inter|^Permanent\ HW\ addr|Aggregator\ ID' /proc/net/bonding/bond0 >> $OUTPUT_FILE
echo >> $OUTPUT_FILE
grep -H ^BONDING /etc/sysconfig/network-scripts/ifcfg-bond?  >> $OUTPUT_FILE
echo >> $OUTPUT_FILE
ethtool bond0 >> $OUTPUT_FILE
echo >> $OUTPUT_FILE
#
#
BOND_INT=(`egrep -i '^slave\ Inter' /proc/net/bonding/bond0 | awk '{print $3}'`)
#
for INT_NAME in ${BOND_INT[@]}
do
        echo "Interface Name = " $INT_NAME >> $OUTPUT_FILE
        BOND_INFO=(`tcpdump -nn -v -i $INT_NAME -s 1500 -c 1 'ether[20:2] == 0x2000' | grep 'Device-ID\|Port-ID\|VLAN' | awk -F: '{print $3}'`)
        echo "Switch Name    = "${BOND_INFO[0]} >> $OUTPUT_FILE
        echo "Switch Port    = "${BOND_INFO[1]} >> $OUTPUT_FILE
        echo "VLAN Name      = "${BOND_INFO[2]} >> $OUTPUT_FILE
        echo >> $OUTPUT_FILE
done
#
cat $OUTPUT_FILE
#
