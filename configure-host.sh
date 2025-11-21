#!/bin/bash

# Ignore TERM, INT, HUP
trap "" TERM INT HUP

VERBOSE=0
HOSTNAME_DESIRED=""
IP_DESIRED=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -n 1)
if [[ ! -f "$NETPLAN_FILE" ]]; then
    echo "Error: No netplan file found in /etc/netplan" >&2
    exit 1
fi
HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/hostname"
LAN_IFACE="eth0"   # adjust if the containers use a different interface

# -------- Helper Output Functions --------
vmsg() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$1"
    fi
}

err() {
    echo "ERROR: $1" >&2
}

# -------- Parse Arguments --------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=1
            shift
            ;;
        -name)
            HOSTNAME_DESIRED="$2"
            shift 2
            ;;
        -ip)
            IP_DESIRED="$2"
            shift 2
            ;;
        -hostentry)
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 3
            ;;
        *)
            err "Unknown option: $1"
            exit 1
    esac
done

# -------- Apply Hostname Change --------
if [[ -n "$HOSTNAME_DESIRED" ]]; then
    CURRENT_HOSTNAME=$(cat "$HOSTNAME_FILE")
    if [[ "$CURRENT_HOSTNAME" != "$HOSTNAME_DESIRED" ]]; then
        vmsg "Changing hostname from $CURRENT_HOSTNAME to $HOSTNAME_DESIRED"

        echo "$HOSTNAME_DESIRED" > "$HOSTNAME_FILE"
        hostnamectl set-hostname "$HOSTNAME_DESIRED" 2>/dev/null

        # Update hosts entry for local machine
        sed -i "/127.0.1.1/s/$CURRENT_HOSTNAME/$HOSTNAME_DESIRED/" "$HOSTS_FILE"

        logger "configure-host.sh: hostname changed from $CURRENT_HOSTNAME to $HOSTNAME_DESIRED"
    else
        vmsg "Hostname already set to $HOSTNAME_DESIRED"
    fi
fi

# -------- Apply IP Address Change --------
if [[ -n "$IP_DESIRED" ]]; then
    CURRENT_IP=$(ip addr show "$LAN_IFACE" | awk '/inet /{print $2}' | cut -d'/' -f1)

    if [[ "$CURRENT_IP" != "$IP_DESIRED" ]]; then
        vmsg "Changing IP from $CURRENT_IP to $IP_DESIRED"

        # Update netplan
        sed -i "s/addresses:.*/addresses: [$IP_DESIRED\/24]/" "$NETPLAN_FILE"
        netplan apply 2>/dev/null

        # Update /etc/hosts local hostname entry
        sed -i "/$HOSTNAME_DESIRED/s/[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}/$IP_DESIRED/" "$HOSTS_FILE"

        logger "configure-host.sh: IP for $LAN_IFACE changed from $CURRENT_IP to $IP_DESIRED"
    else
        vmsg "IP already set to $IP_DESIRED"
    fi
fi

# -------- Ensure Host Entry in /etc/hosts --------
if [[ -n "$HOSTENTRY_NAME" && -n "$HOSTENTRY_IP" ]]; then
    if grep -q "$HOSTENTRY_NAME" "$HOSTS_FILE"; then
        # If name exists, update IP if necessary
        EXISTING_IP=$(grep "$HOSTENTRY_NAME" "$HOSTS_FILE" | awk '{print $1}')
        if [[ "$EXISTING_IP" != "$HOSTENTRY_IP" ]]; then
            vmsg "Updating hosts entry for $HOSTENTRY_NAME"
            sed -i "s/^.*$HOSTENTRY_NAME/$HOSTENTRY_IP $HOSTENTRY_NAME/" "$HOSTS_FILE"
            logger "configure-host.sh: updated host entry $HOSTENTRY_NAME to $HOSTENTRY_IP"
        else
            vmsg "/etc/hosts already contains $HOSTENTRY_NAME $HOSTENTRY_IP"
        fi
    else
        vmsg "Adding new host entry: $HOSTENTRY_IP $HOSTENTRY_NAME"
        echo "$HOSTENTRY_IP $HOSTENTRY_NAME" >> "$HOSTS_FILE"
        logger "configure-host.sh: added host entry $HOSTENTRY_NAME $HOSTENTRY_IP"
    fi
fi

exit 0
