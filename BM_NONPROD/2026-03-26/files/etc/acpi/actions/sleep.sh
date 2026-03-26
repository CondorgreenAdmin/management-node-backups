#!/bin/sh

PATH=/sbin:/bin:/usr/bin
READAHEAD_FILE=/sys/kernel/mm/swap/vma_ra_enabled
PAGE_CLUSTER_FILE=/proc/sys/vm/page-cluster

do_swapoff()
{
        local swap_file=$1
        local readahead
        local page_cluster

        readahead=$(cat $READAHEAD_FILE)
        page_cluster=$(cat $PAGE_CLUSTER_FILE)

        # Enable global readahead with page-cluster=8. This was found to
        # better swapoff performance in AWS instances than the default
        # VMA readhead algorithm with page-cluster=3.
        #
        # page-cluster=8 is a bit of a magical number, take it as just
        # a better default for AWS. It may need to be adjusted per
        # workload through.
        echo false > $READAHEAD_FILE
        echo 8 > $PAGE_CLUSTER_FILE

        swapoff $swap_file

        echo $readahead > $READAHEAD_FILE
        echo $page_cluster > $PAGE_CLUSTER_FILE
}

# Hibernation selects the swapfile with highest priority. Since there may be
# other swapfiles configured, ensure /swap is selected as hibernation
# target by setting to maximum priority.
swap_priority=32767

set -x

case "$2" in
    LNXSLPBN:*)
        # The iteration had been placed here to add retry logic to hibernation
        # in case of failures and to avoid force stop of instances after 20min
        logger -t hibernate -p user.notice "Got $2 event, going to hibernate"

        for i in 1 2 3
        do
          if swapon --priority=$swap_priority /swap && sleep 1 && /usr/sbin/pm-hibernate; then
                break
          else
                logger -t hibernate -p user.notice "Failed iteration $i"
                do_swapoff /swap
                sleep 10
          fi
       done
       ;;
    *)
        logger -t hibernate "ACPI action undefined: $2" ;;
esac
