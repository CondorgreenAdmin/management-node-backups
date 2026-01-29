#!/bin/bash

#
# WARNING: If you happen to edit this file then get the SHA256 using 'sha256sum setup_iptable_rules.sh' command
# and modify the edr/include/Constants.h isolate_script_hash variable with the new SHA
#

MDE_IPTABLE_BASE_CMD="iptables "     
MDE_IP6TABLE_BASE_CMD="ip6tables "   
MDE_CHAIN=mdechain
MDE_PACKET_STAMP="-m mark ! --mark 0x1/0x1"
MDE_NFQUEUE_BYPASS="NFQUEUE --queue-num 0 --queue-bypass"
MDE_TCP_PACKET_FILTER="-p tcp --tcp-flags FIN,SYN,RST,ACK,PSH SYN"
MDE_TCP_PACKET_FILTER_SAVE="-m tcp --tcp-flags FIN,SYN,RST,PSH,ACK SYN"
MDE_UDP_PACKET_FILTER="-p udp"
MDE_IPTABLE_TCP_REJECT_WITH_UNREACHABLE="--reject-with icmp-port-unreachable"
MDE_IP6TABLE_TCP_REJECT_WITH_UNREACHABLE="--reject-with icmp6-port-unreachable"
MDE_SUSE_FW="SuSEfirewall2"
MDE_RETRY_COUNT=3
MDE_RETRY_DELAY=10s
MDE_ALREADY_EXIST_CODE=17
ISOLATE_SETTINGS_KEY='"isDeviceIsolated"'

WDAV_SETTINGS_PATH='/var/opt/microsoft/mdatp/wdavstate'
process_name="mdatp"

if [ "$(id -u)" != "0" ] ; then
   logger -p daemon.err -t "setup_iptables_rules" "User has insufficient privilege"
   echo "setup_iptables_rules" "User has insufficient privilege"
   exit 4
fi

function retry(){
    local n=1
    cmd="$@"
    while true; do
        echo "retry command \"$@\" attempt $n/$MDE_RETRY_COUNT."
        output=$($cmd 2>&1) || exitcode="$?"
        if [[ $exitcode -eq 0 ]]; then
            echo "command '"$@"' succeeded attempt $n/$MDE_RETRY_COUNT."
            return 0
        fi
        # iptables commands exit codes are 
        #   0 - correct functioning
        #   1 - any error that is not related to command line parameters
        #   2 - invalid or abused command line parameters
        #   4 - retry command failed, actual exit code will reported as part of script output.
        # in case command failed due to already existing chain\rule should handle it differently.
        if [[ $exitcode -eq 1 ]] && [[ $output == *"already exists"* ]]; then 
            echo "retry command already exists code attempt $n/$MDE_RETRY_COUNT."
            return $MDE_ALREADY_EXIST_CODE
        fi
        echo "retry command failed attempt $n/$MDE_RETRY_COUNT: output: $output, exitcode: $exitcode"
        if [[ $n -le $MDE_RETRY_COUNT ]]; then
            ((n++))
            sleep $MDE_RETRY_DELAY
        else
            exit 4
        fi
    done
}

run_or_fail() {
   cmd="$@"
   status="0"
   out=$($cmd 2>&1) || status="$?"
   
   if [ "$status" != "0" ]; then
      cmd=$(echo $cmd | /bin/sed 's/[[:space:]]/ /g')
      logger -p daemon.err -t "setup_iptables_rules" "Failed to run: \"$cmd\", error code: $status, \"$out\""
      echo "setup_iptables_rules" "Failed to run: \"$cmd\", error code: $status, \"$out\""
      exit 4
   fi
}

run_or_warn() {
   cmd="$@"
   status="0"
   out=$($cmd 2>&1) || status="$?"
   
   if [ "$status" != "0" ]; then
      cmd=$(echo $cmd | /bin/sed 's/[[:space:]]/ /g')
      logger -p daemon.warn -t "cleanup_iptables_rules" "\"$cmd\" returns with code: $status, message: \"$out\""
      echo "cleanup_iptables_rules" "Failed to run: \"$cmd\", error code: $status, \"$out\""
      return 4
   fi
}

retrieve_expected_rules() {
   trap 'catch_failed_isolation_status $LINENO' ERR

   local whether_use_ipv6=$1

   edr_expected_rules=()

   # Reject all other traffic (removed -p all)
   if [[ $whether_use_ipv6 == true ]]; then
      edr_expected_rules+=("OUTPUT ! -o lo -j REJECT ${MDE_IP6TABLE_TCP_REJECT_WITH_UNREACHABLE}")
   else
      edr_expected_rules+=("OUTPUT ! -o lo -j REJECT ${MDE_IPTABLE_TCP_REJECT_WITH_UNREACHABLE}")
   fi

   # Intercept TCP inbound connection
   edr_expected_rules+=("INPUT ! -i lo -p tcp ${MDE_PACKET_STAMP} ${MDE_TCP_PACKET_FILTER_SAVE} -j ${MDE_CHAIN}")

   # Allow inbound ssh (added -m tcp)
   # edr_expected_rules+=("INPUT -i eth0 -p tcp -m tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT")

   # Allow DNS packets
   edr_expected_rules+=("INPUT -p udp -m udp --sport 53 -j ACCEPT")
   edr_expected_rules+=("INPUT -p udp -m udp --dport 53 -j ACCEPT")
   
    # Intercept TCP outbound connection rules
   edr_expected_rules+=("OUTPUT ! -o lo -p tcp ${MDE_PACKET_STAMP} ${MDE_TCP_PACKET_FILTER_SAVE} -j ${MDE_CHAIN}")

   # Allow inbound ssh connection traffic (added -m tcp)
   # edr_expected_rules+=("OUTPUT -o eth0 -p tcp -m tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT")

   # Allow packets owned by mdatp GID
   gid=$(id -g $process_name)
   edr_expected_rules+=("OUTPUT -m owner --gid-owner $gid -j ACCEPT")

   # Allow DNS traffic   
   edr_expected_rules+=("OUTPUT -p udp -m udp --sport 53 -j ACCEPT")
   edr_expected_rules+=("OUTPUT -p udp -m udp --dport 53 -j ACCEPT")
   
   edr_expected_rules+=("${MDE_CHAIN} -j ${MDE_NFQUEUE_BYPASS}")
}

retrieve_ignored_keywords() {

   ignored_keywords=()
   ignored_keywords+=("-j REJECT")  
   ignored_keywords+=("-j DROP")
}

retrieve_applied_rules() {
   trap 'catch_failed_isolation_status $LINENO' ERR

   local whether_use_ipv6=$1

    # Retrieve applied rules using ip6tables
   if [[ $whether_use_ipv6 == true ]]; then 
      echo "Using $MDE_IP6TABLE_BASE_CMD"
      iptables_s_cmd="$MDE_IP6TABLE_BASE_CMD -S"
   else
      echo "Using $MDE_IPTABLE_BASE_CMD"
      iptables_s_cmd="$MDE_IPTABLE_BASE_CMD -S"
   fi
   
   run_or_fail $iptables_s_cmd
   iptables_output=$out

   # Filter only rules (start with -A) and cut the prefix of "-A"
   applied_rules=$(echo "$iptables_output" | grep -E '^-A' | cut -c 4-)      

   # Convert string to an array
   mapfile -t applied_rules_map <<< "$applied_rules" 
}

check_ip6_isolation_status() {   
   check_isolation_status true
}

check_isolation_status() {
   trap 'catch_failed_isolation_status $LINENO' ERR

   local use_ipv6=$1

   # Retrieve expected and applied rules for all tables: INPUT, OUTPUT, mdechain
   retrieve_expected_rules use_ipv6
   retrieve_applied_rules use_ipv6
    
   array=("INPUT" "OUTPUT" "mdechain")
   for table in "${array[@]}"; do

      table_expected_rules=()
      table_applied_rules=()

      for rule in "${edr_expected_rules[@]}"; do
         if [[ $rule == *"$table"* ]]; then
            table_expected_rules+=("$rule")
         fi
      done

      for rule in "${applied_rules_map[@]}"; do
         if [[ $rule == *"$table"* ]]; then
            table_applied_rules+=("$rule")
         fi
      done

      retrieve_ignored_keywords 

      # First verify that the number of applied rules are equal or more than expected rules
      # If less, then device is not isolated
      applied_rules_length=${#table_applied_rules[@]}
      edr_expected_rules_length=${#table_expected_rules[@]}
      if (( $applied_rules_length < $edr_expected_rules_length )); then
         echo "$table applied rules are less than expected (#expected=$edr_expected_rules_length #applied=$applied_rules_length)"
         echo "Device is not isolated"
         exit 101
      fi  

      # Compare expected rules to applied rules (ignore ignored_rules), break when there are no more edr_expected_rules
      # Order is ignored, as long as the top rules are expected_rule or ignored_rule   
      expected_rules_found=0
      ignored_rules_found=0
      for((applied_rule_index=0; applied_rule_index<applied_rules_length; applied_rule_index++)); do

         # When all expected rules are found, return
         if (( $edr_expected_rules_length == $expected_rules_found )); then
            break;
         fi
      
         # Check if applied rule is defined in expected, if so, remove it from expected list
         applied_rule=${table_applied_rules[applied_rule_index]}      
         if [[ " ${table_expected_rules[*]} " == *" $applied_rule "* ]]; then         
            table_expected_rules=("${table_expected_rules[@]/$applied_rule}")
            expected_rules_found=$((expected_rules_found+1))
            continue;
         fi   

         # Check whether applied rule is defined in ignored
         found_ignored_rule=false

         for ignored_keyword in "${ignored_keywords[@]}"; do
            if [[ "$applied_rule" =~ "$ignored_keyword" ]]; then
               found_ignored_rule=true
               ignored_rules_found=$((ignored_rules_found+1))
               break;
            fi
         done

         if [[ $found_ignored_rule == true ]]; then
            continue
         fi
         
         echo "Device not isolated, rule not expected: $applied_rule"
         exit 101
      done

      if (( $edr_expected_rules_length == $expected_rules_found )); then
         echo -e "All $edr_expected_rules_length $table rules were found ($ignored_rules_found ignored rules)"
      else
         echo -e "No all $edr_expected_rules_length $table rules were found (only $expected_rules_found)"
         exit 101
      fi
   done
}

###
# "iptables -I" inserts the rule at the begining of the rules tables.
# This means that the lasT rule to be inserted with "iptables -I" will be the first rule to be checked on the firewall.
# Thus the following commands create "stack" of rules to check, where the first rule inserted is the last to be checked (LIFO)
###
setup_iptable_rules() {
   echo "Setting up iptables rules"
   retry "$MDE_IPTABLE_BASE_CMD -N ${MDE_CHAIN}"
   if [ $? -eq $MDE_ALREADY_EXIST_CODE ]; then   
      echo "iptables already setup"
      echo "iptables rules setup completed"
      return 0
   fi
   
   # Reject all other traffic
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT ! -o lo --protocol all -j REJECT --reject-with icmp-port-unreachable"

   ### Input chain rule ###
   # Intercept TCP inbound connection
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I INPUT ${MDE_PACKET_STAMP} ! -i lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_fail "iptables -I INPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"

   # Allow inbound ssh
   # run_or_fail "$MDE_IPTABLE_BASE_CMD -I INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT"
   
   # Allow DNS packets
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I INPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I INPUT --protocol udp --dport 53 -j ACCEPT"

   ### Output chain rule ###
   # Intercept TCP outbound connection rules
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT ${MDE_PACKET_STAMP} ! -o lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_fail "iptables -I OUTPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"

   # Allow inbound ssh connection traffic
   # run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT"

   # Allow packets owned by mdatp GID
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT -m owner --gid-owner $process_name -j ACCEPT"

   # Allow DNS traffic
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I OUTPUT --protocol udp --dport 53 -j ACCEPT"
   
   run_or_fail "$MDE_IPTABLE_BASE_CMD -I ${MDE_CHAIN} -j ${MDE_NFQUEUE_BYPASS}"

   $MDE_IPTABLE_BASE_CMD -L
   echo "iptables rules setup completed"
}

setup_ip6table_rules() {
   echo "Setting up ip6tables rules"
   
   retry "$MDE_IP6TABLE_BASE_CMD -N ${MDE_CHAIN}"
   if [ $? -eq $MDE_ALREADY_EXIST_CODE ]; then   
      echo "ip6tables already setup"
      echo "ip6tables rules setup completed"
      return 0
   fi

   # Reject all other traffic
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT ! -o lo --protocol all -j REJECT --reject-with icmp6-port-unreachable"

   ### Input chain rule ###
   # Intercept TCP inbound connection
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I INPUT ${MDE_PACKET_STAMP} ! -i lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_fail "iptables -I INPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"

   # Allow inbound ssh
   # run_or_fail "$MDE_IP6TABLE_BASE_CMD -I INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT"
   
   # Allow DNS packets
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I INPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I INPUT --protocol udp --dport 53 -j ACCEPT"

   ### Output chain rule ###
   # Intercept TCP outbound connection rules
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT ${MDE_PACKET_STAMP} ! -o lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_fail "iptables -I OUTPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"

   # Allow inbound ssh connection traffic
   # run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT"

   # Allow packets owned by mdatp GID
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT -m owner --gid-owner $process_name -j ACCEPT"

   # Allow DNS traffic
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I OUTPUT --protocol udp --dport 53 -j ACCEPT"

   run_or_fail "$MDE_IP6TABLE_BASE_CMD -I ${MDE_CHAIN} -j ${MDE_NFQUEUE_BYPASS}"

   $MDE_IP6TABLE_BASE_CMD -L
   echo "ip6tables rules setup completed"
}

cleanup_iptable_rules() {
   echo "Flush iptables rules"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT ! -o lo --protocol all -j REJECT --reject-with icmp-port-unreachable"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D INPUT ${MDE_PACKET_STAMP} ! -i lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IPTABLE_BASE_CMD -D INPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IPTABLE_BASE_CMD -D INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D INPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D INPUT --protocol udp --dport 53 -j ACCEPT"

   run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT ${MDE_PACKET_STAMP} ! -o lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT -m owner --gid-owner $process_name -j ACCEPT"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D OUTPUT --protocol udp --dport 53 -j ACCEPT"
   
   run_or_warn "$MDE_IPTABLE_BASE_CMD -D ${MDE_CHAIN} -j ${MDE_NFQUEUE_BYPASS}"
   run_or_warn "$MDE_IPTABLE_BASE_CMD -X ${MDE_CHAIN}"
   $MDE_IPTABLE_BASE_CMD -L
   echo "Cleaned up all iptables rules"
}

cleanup_ip6table_rules() {
   echo "Flush ip6tables rules"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT ! -o lo --protocol all -j REJECT --reject-with icmp6-port-unreachable"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D INPUT ${MDE_PACKET_STAMP} ! -i lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IP6TABLE_BASE_CMD -D INPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IP6TABLE_BASE_CMD -D INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D INPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D INPUT --protocol udp --dport 53 -j ACCEPT"

   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT ${MDE_PACKET_STAMP} ! -o lo ${MDE_TCP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT ${MDE_PACKET_STAMP} ${MDE_UDP_PACKET_FILTER} -j ${MDE_CHAIN}"
   #run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT -m owner --gid-owner $process_name -j ACCEPT"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT --protocol udp --sport 53 -j ACCEPT"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D OUTPUT --protocol udp --dport 53 -j ACCEPT"
   
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -D ${MDE_CHAIN} -j ${MDE_NFQUEUE_BYPASS}"
   run_or_warn "$MDE_IP6TABLE_BASE_CMD -X ${MDE_CHAIN}"
   $MDE_IP6TABLE_BASE_CMD -L
   echo "Cleaned up all ip6tables rules"
}

wait_for_active_service() {
   local n=1
   local ret_code=0
   while true; do
      output=$(systemctl status $1 2>&1) || ret_code="$?"
      echo "setup_iptable wait for service: $output, exitcode: $ret_code"
      if [[ $output == *" active "* ]]; then 
         echo "setup_iptable $1 is active"
         return 0;
      fi
      if [[ $n -le $3 ]]; then
           ((n++))
           sleep $2
      else
           # not failing since could be service not installed or not enabled,
           # both returns exit code 3 in SUSE.
           # best effort to wait for service startup on reboot.
           return 0; 
      fi
      
   done
}

#
# prerequisite prior to running iptables commands.
#
validate_prerequisite() {
   output=$(cat /etc/os-release 2>&1) || exitcode="$?"
   shopt -s nocasematch # case-insensitive match 
   if [[ $output == *"SUSE"* ]]; then 
      echo "setup_iptable: SUSE distro found, $output"

      # best effort to wait for SUSE-FW to be active.
      # usually the service is already active except on-reboot.
      wait_for_active_service $MDE_SUSE_FW $MDE_RETRY_DELAY $MDE_RETRY_COUNT
      return 0
   fi
   # add here other prerequisite here if needed.
}

#
# Cleanup IPv4 and IPv6 isolation rules
#
clean_rules() {
   cleanup_iptable_rules
   if test -f /proc/net/if_inet6; then 
      echo "IPv6 interface is avaialble";
      cleanup_ip6table_rules
   else 
      echo "IPv6 Interface is not available"; 
   fi
}

#
# Cleanup MDE persisted settings to keep machine unisolated after roboot.
#
clean_settings(){
   echo "Cleaning MDE settings"
   # in-place settings update
   run_or_fail "sed -i "s/$ISOLATE_SETTINGS_KEY:true/$ISOLATE_SETTINGS_KEY:false/g" $WDAV_SETTINGS_PATH"
}

catch_failed_isolation_status() {
   echo "catch_failed_isolation_status: failed to execute: $BASH_COMMAND, on line number: $1, exit code: $?"
   exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
   case $1 in
      -i) 
         action="install"
         ;;
      -u) 
         action="uninstall"
         ;;
      -f) 
         action="force_cleanup"
         ;;
      -c) 
         action="check_status"
         ;;
      -s) 
         WDAV_SETTINGS_PATH="$2"
         shift
         ;;
      test)
         process_name="root" # In case running in test mode and mdatp isn't installed, use a root group for gid-owner
         ;;

      *) 
         echo "Parts of the command couldn't be recognized, including: '-flag'" > /dev/stderr
         exit 1
         ;;
   esac
   shift
done

# Perform actions based on the parsed arguments
if [ "$action" = "install" ]; then
   validate_prerequisite
   setup_iptable_rules
   if test -f /proc/net/if_inet6; then 
      echo "IPv6 interface is available"
      setup_ip6table_rules
   else 
      echo "Interface is not available"
   fi
elif [ "$action" = "uninstall" ]; then
   echo "Cleanup firewall rules"
   clean_rules
elif [ "$action" = "force_cleanup" ]; then 
   # force isolation cleanup including MDE settings.
   echo "Force un-isolation and clean settings"
   if ! test -f $WDAV_SETTINGS_PATH; then 
      echo "State file doesn't exist"
      exit 1
   fi
   clean_settings
   clean_rules
elif [ "$action" = "check_status" ]; then
   check_isolation_status
   if test -f /proc/net/if_inet6; then 
      check_ip6_isolation_status
   fi
   # Device is isolated
   echo "Device is isolated"
   exit 100
else
   echo "Parts of the command couldn't be recognized, including: '-flag'" > /dev/stderr
   exit 1
fi
