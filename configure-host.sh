#!/bin/bash
# configure-host.sh
# Configure basic host settings: hostname, IP, and host entries.

# Ignore termination signals
trap '' TERM HUP INT

VERBOSE=0
HOSTNAME_OPT=""
IP_OPT=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

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
        -name)
            HOSTNAME_OPT="$2"
            shift 2
            ;;
        -ip)
            IP_OPT="$2"
            shift 2
            ;;
        -hostentry)
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Configure hostname/IP ---
if [ -n "$HOSTNAME_OPT" ] && [ -n "$IP_OPT" ]; then
    CURRENT_HOSTNAME=$(hostname)
    if [ "$CURRENT_HOSTNAME" != "$HOSTNAME_OPT" ]; then
        vprint "Updating hostname from $CURRENT_HOSTNAME to $HOSTNAME_OPT"
        echo "$HOSTNAME_OPT" | sudo tee /etc/hostname >/dev/null
        sudo hostnamectl set-hostname "$HOSTNAME_OPT"
        logger "configure-host.sh: Hostname changed from $CURRENT_HOSTNAME to $HOSTNAME_OPT"
    else
        vprint "Hostname already set to $HOSTNAME_OPT"
    fi

    # Remove any old 'server1' or 'loghost' lines
    sudo sed -i -E '/^192\.168\.16\.241[[:space:]]+server1$/d' /etc/hosts
    sudo sed -i -E '/^192\.168\.16\.3[[:space:]]+loghost$/d' /etc/hosts
    sudo sed -i -E '/^192\.168\.16\.4[[:space:]]+webhost$/d' /etc/hosts

    # Insert the desired entry
    echo "$IP_OPT    $HOSTNAME_OPT" | sudo tee -a /etc/hosts >/dev/null
    vprint "Ensured /etc/hosts entry: $IP_OPT $HOSTNAME_OPT"
fi

# --- Preserve management entry dynamically ---
CURRENT_HOST=$(hostname)

if [[ "$CURRENT_HOST" == "server1" || "$HOSTNAME_OPT" == "loghost" ]]; then
    # Ensure server1-mgmt exists only on server1
    if ! grep -q '^172\.16\.1\.241[[:space:]]\+server1-mgmt$' /etc/hosts; then
        echo "172.16.1.241    server1-mgmt" | sudo tee -a /etc/hosts >/dev/null
        vprint "Ensured /etc/hosts entry: 172.16.1.241 server1-mgmt"
    fi
elif [[ "$CURRENT_HOST" == "server2" || "$HOSTNAME_OPT" == "webhost" ]]; then
    # Ensure server2-mgmt exists only on server2
    if ! grep -q '^172\.16\.1\.242[[:space:]]\+server2-mgmt$' /etc/hosts; then
        echo "172.16.1.242    server2-mgmt" | sudo tee -a /etc/hosts >/dev/null
        vprint "Ensured /etc/hosts entry: 172.16.1.242 server2-mgmt"
    fi
fi

# --- Preserve openwrt entries ---
if ! grep -q '^192\.168\.16\.2[[:space:]]\+openwrt$' /etc/hosts; then
    echo "192.168.16.2    openwrt" | sudo tee -a /etc/hosts >/dev/null
fi
if ! grep -q '^172\.16\.1\.2[[:space:]]\+openwrt-mgmt$' /etc/hosts; then
    echo "172.16.1.2      openwrt-mgmt" | sudo tee -a /etc/hosts >/dev/null
fi

# --- Configure host entry (optional) ---
if [ -n "$HOSTENTRY_NAME" ] && [ -n "$HOSTENTRY_IP" ]; then
    if ! grep -q "^$HOSTENTRY_IP[[:space:]]\+$HOSTENTRY_NAME$" /etc/hosts; then
        echo "$HOSTENTRY_IP    $HOSTENTRY_NAME" | sudo tee -a /etc/hosts >/dev/null
        vprint "Added host entry $HOSTENTRY_NAME -> $HOSTENTRY_IP"
        logger "configure-host.sh: Added host entry $HOSTENTRY_NAME -> $HOSTENTRY_IP"
    else
        vprint "Host entry $HOSTENTRY_NAME already set to $HOSTENTRY_IP"
    fi
fi
