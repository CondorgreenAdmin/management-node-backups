#!/bin/sh

PATH=/sbin:/bin:/usr/bin

# Hibernation selects the swapfile with highest priority. Since there may be
# other swapfiles configured, ensure /swap is selected as hibernation
# target by setting to maximum priority.
swap_priority=32767

LOCKFILE=/var/run/hibernate.lock
HIBERNATE_STATE_DIR=/var/run/hibernate
HIBERNATED_AT="$HIBERNATE_STATE_DIR/hibernated_at"
RESUMED_AT="$HIBERNATE_STATE_DIR/resumed_at"
STALE_THRESHOLD=30
LOGNAME="hibernate"

READAHEAD_FILE=/sys/kernel/mm/swap/vma_ra_enabled
PAGE_CLUSTER_FILE=/proc/sys/vm/page-cluster

log() {
    local level="$1"
    local message="$2"
    logger -t "$LOGNAME" -p "user.$level" "[PID $$] $message"
}

do_swapoff() {
    local swap_file=$1

    # Only modify readahead if the file exists
    if [ -f "$READAHEAD_FILE" ]; then
        local readahead=$(cat $READAHEAD_FILE)
        local page_cluster=$(cat $PAGE_CLUSTER_FILE)

        # Enable global readahead with page-cluster=8. This was found to
        # better swapoff performance in AWS instances than the default
        # VMA readahead algorithm with page-cluster=3.
        #
        # page-cluster=8 is a bit of a magical number, take it as just
        # a better default for AWS. It may need to be adjusted per
        # workload through.
        echo false > $READAHEAD_FILE
        echo 8 > $PAGE_CLUSTER_FILE

        swapoff $swap_file

        echo $readahead > $READAHEAD_FILE
        echo $page_cluster > $PAGE_CLUSTER_FILE
    else
        swapoff $swap_file
    fi
}

should_hibernate() {
    local now=$(date +%s)

    if [ -f "$RESUMED_AT" ]; then
        local resumed=$(cat "$RESUMED_AT")
        local since_resume=$((now - resumed))

        if [ $since_resume -lt $STALE_THRESHOLD ]; then
            log notice "Resumed ${since_resume}s ago, skipping"
            return 1
        fi

        return 0
    fi

    if [ -f "$HIBERNATED_AT" ]; then
        local hibernated=$(cat "$HIBERNATED_AT")
        local since_hibernate=$((now - hibernated))

        if [ $since_hibernate -lt $STALE_THRESHOLD ]; then
            log notice "Hibernation started ${since_hibernate}s ago, skipping"
            return 1
        fi

        log notice "Stale hibernated_at (${since_hibernate}s old), clearing"
        rm -f "$HIBERNATED_AT"
        return 0
    fi

    return 0
}

do_hibernate() {
    local event="$1"

    for i in 1 2 3; do
        log notice "Attempt $i/3: Enabling swap"

        if ! swapon --priority=$swap_priority /swap; then
            log err "Attempt $i/3: Failed to enable swap, retrying in 10s"
            sleep 10
            continue
        fi

        log notice "Attempt $i/3: Swap enabled, initiating hibernation"
        sleep 1

        if /usr/sbin/pm-hibernate; then
            log notice "Hibernation initiated"
            return 0
        else
            log err "Attempt $i/3: Hibernation initiation failed, disabling swap, retrying in 10s"
            do_swapoff /swap
            sleep 10
        fi
    done

    log err "All hibernation attempts failed"
    rm -f "$HIBERNATED_AT"
    return 1
}

mkdir -p "$HIBERNATE_STATE_DIR"

case "$2" in
    LNXSLPBN:*|SBTN)
        if ! should_hibernate; then
            log notice "ACPI event $2 ignored"
            exit 0
        fi

        rm -f "$RESUMED_AT"
        hibernated_time=$(date +%s)
        log notice "Hibernation requested at $hibernated_time"
        echo "$hibernated_time" > "$HIBERNATED_AT"

        exec 200>"$LOCKFILE"

        if flock -n 200; then
            log notice "ACPI event $2 received, initiating hibernation"
            do_hibernate "$2"
        else
            log notice "ACPI event $2 ignored, hibernation already in progress"
        fi
        ;;
    *)
        log warning "Unknown ACPI event: $2"
        ;;
esac
