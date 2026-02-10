#!/bin/bash

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
        echo false > $READAHEAD_FILE
        echo 8 > $PAGE_CLUSTER_FILE

        swapoff $swap_file

        echo $readahead > $READAHEAD_FILE
        echo $page_cluster > $PAGE_CLUSTER_FILE
}

if [ "$1" = "thaw" ] ; then
    logger -t hibernate "Resuming from sleep to swapoff"
    do_swapoff /swap
fi