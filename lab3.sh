#!/bin/bash

# Regin Ian

VERBOSE=0
REMOTE_FLAGS=""

if [[ "$1" == "-verbose" ]]; then
    VERBOSE=1
    REMOTE_FLAGS="-verbose"
fi

run_or_fail() {
    "$@"
    if [[ $? -ne 0 ]]; then
        echo "ERROR running: $@" >&2
        exit 1
    fi
}

echo "Deploying configure-host.sh to server1-mgmt..."
run_or_fail scp configure-host.sh remoteadmin@server1-mgmt:/root

echo "Running configuration on server1-mgmt..."
run_or_fail ssh remoteadmin@server1-mgmt -- /root/configure-host.sh $REMOTE_FLAGS \
    -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4

echo "Deploying configure-host.sh to server2-mgmt..."
run_or_fail scp configure-host.sh remoteadmin@server2-mgmt:/root

echo "Running configuration on server2-mgmt..."
run_or_fail ssh remoteadmin@server2-mgmt -- /root/configure-host.sh $REMOTE_FLAGS \
    -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3

echo "Updating local host entries..."
run_or_fail sudo ./configure-host.sh $REMOTE_FLAGS -hostentry loghost 192.168.16.3
run_or_fail sudo ./configure-host.sh $REMOTE_FLAGS -hostentry webhost 192.168.16.4

echo "Lab 3 configuration completed successfully."
