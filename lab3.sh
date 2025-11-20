#!/bin/bash
# lab3.sh
# This script transfers configure-host.sh to two servers, runs it remotely,
# and updates the local /etc/hosts file. Supports -verbose option.

trap '' TERM HUP INT   # ignore signals

VERBOSE=0
CONFIG_SCRIPT="./configure-host.sh"

# Helper for verbose output
vprint() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$@"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if configure-host.sh exists and is executable
if [ ! -x "$CONFIG_SCRIPT" ]; then
    echo "Error: $CONFIG_SCRIPT not found or not executable"
    exit 1
fi

# Build verbose flag for remote/local runs
VERBOSE_FLAG=""
if [ "$VERBOSE" -eq 1 ]; then
    VERBOSE_FLAG="-verbose"
fi

# Function to transfer and run configure-host.sh on a remote server
run_remote() {
    local server="$1"
    local args="$2"

    vprint "Transferring $CONFIG_SCRIPT to $server..."
    scp "$CONFIG_SCRIPT" "remoteadmin@$server:/root" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to transfer $CONFIG_SCRIPT to $server"
        return 1
    fi

    vprint "Running configure-host.sh on $server with args: $args $VERBOSE_FLAG"
    ssh "remoteadmin@$server" -- "/root/configure-host.sh $args $VERBOSE_FLAG"
    if [ $? -ne 0 ]; then
        echo "Error: configure-host.sh failed on $server"
        return 1
    fi
}

# --- Apply configurations ---
run_remote "server1-mgmt" "-name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4" || exit 1
run_remote "server2-mgmt" "-name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3" || exit 1

# Update local /etc/hosts entries
vprint "Updating local /etc/hosts for loghost and webhost..."
$CONFIG_SCRIPT -hostentry loghost 192.168.16.3 $VERBOSE_FLAG
if [ $? -ne 0 ]; then
    echo "Error: configure-host.sh failed locally for loghost"
    exit 1
fi

$CONFIG_SCRIPT -hostentry webhost 192.168.16.4 $VERBOSE_FLAG
if [ $? -ne 0 ]; then
    echo "Error: configure-host.sh failed locally for webhost"
    exit 1
fi

vprint "Configuration completed successfully."
exit 0
