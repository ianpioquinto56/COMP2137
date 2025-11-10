#!/bin/bash

# Configuration Script for Assignment 2
# Target Container: server1

CONTAINER_NAME="server1"
TARGET_ADDRESS="192.168.16.21/24"
TARGET_IP="192.168.16.21"
DENNIS_EXTERNAL_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

# List of users to create
USERS=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

# --- Function to Run Commands Inside the Container ---
# NOTE: Using 'incus exec'. Replace with 'lxc exec' if your environment uses LXD instead of Incus.
run_in_container() {
    # Check for success and print errors only if needed
    incus exec "${CONTAINER_NAME}" -- /bin/bash -c "$1" || {
        echo "ERROR: Failed to execute command inside container ${CONTAINER_NAME}: $1" >&2
        return 1
    }
}

# --------------------------------------------------------------------------------------
## 1. Networking Configuration
# --------------------------------------------------------------------------------------
configure_network() {
    echo "--- 1. Configuring Network Interface and /etc/hosts ---"
    
    # Critical Assumption: The interface for the 192.168.16 network is eth1.
    NETPLAN_CMD=$(cat <<EOF
    # 1.1 Netplan Configuration
    # Find the primary Netplan file (assuming one exists for configuration)
    NETPLAN_FILE=\$(ls /etc/netplan/*.yaml | head -n 1)
    
    # Overwrite the file to ensure persistent configuration is exactly as required.
    # We explicitly keep eth0 (mgmt interface) configured via DHCP and set eth1 statically.
    cat > \${NETPLAN_FILE} <<EOT
    network:
      version: 2
      renderer: networkd
      ethernets:
        eth0: # Assuming this is the mgmt network interface (DO NOT ALTER)
          dhcp4: true
        eth1: # Assuming this is the 192.168.16 network interface
          addresses: [${TARGET_ADDRESS}]
          nameservers:
            addresses: [8.8.8.8, 8.8.4.4] # Add public DNS for package downloads
    EOT
    
    # Apply the new network configuration
    netplan apply
EOF
)
    run_in_container "${NETPLAN_CMD}"
    
    # 1.2 /etc/hosts Configuration
    echo "--- Updating /etc/hosts file ---"
    
    HOSTS_CMD=$(cat <<EOF
    # Remove old entries for server1 that are NOT loopback (127.0.0.1)
    sed -i '/server1/d' /etc/hosts
    # Add the new, correct entry
    echo "${TARGET_IP} server1" >> /etc/hosts
EOF
)
    run_in_container "${HOSTS_CMD}"
    echo "Network and /etc/hosts updated."
}

# --------------------------------------------------------------------------------------
## 2. Software Installation
# --------------------------------------------------------------------------------------
install_software() {
    echo "--- 2. Installing Software: apache2 and squid ---"
    
    SOFTWARE_CMD=$(cat <<EOF
    export DEBIAN_FRONTEND=noninteractive
    
    # Update packages and install apache2 and squid
    apt update
    apt install -y apache2 squid
    
    # Ensure services are enabled and running in their default configuration
    systemctl enable apache2
    systemctl start apache2
    systemctl enable squid
    systemctl start squid
    
    # Check service status (optional confirmation)
    systemctl is-active apache2
    systemctl is-active squid
EOF
)
    run_in_container "${SOFTWARE_CMD}"
    echo "apache2 and squid installed and active."
}

# --------------------------------------------------------------------------------------
## 3. User and SSH Key Configuration
# --------------------------------------------------------------------------------------
configure_users() {
    echo "--- 3. Configuring Users and SSH Keys ---"

    for USER in "${USERS[@]}"; do
        echo "--> Processing user: ${USER}"

        # Determine if the user needs sudo access
        SUDO_GROUP=""
        if [ "${USER}" == "dennis" ]; then
            SUDO_GROUP="-G sudo"
        fi

        USER_CMD=$(cat <<EOF
        # 3.1 Create user with home directory, bash shell, and group membership
        useradd -m -s /bin/bash ${SUDO_GROUP} ${USER}

        # 3.2 Setup SSH directory and permissions
        mkdir -p /home/${USER}/.ssh
        chown -R ${USER}:${USER} /home/${USER}/.ssh
        chmod 700 /home/${USER}/.ssh

        # 3.3 Generate SSH key pair (RSA and ED25519)
        # Generate keys without a passphrase (-N '') and use su to run as the user
        su - ${USER} -c "ssh-keygen -t rsa -N '' -f /home/${USER}/.ssh/id_rsa" > /dev/null 2>&1
        su - ${USER} -c "ssh-keygen -t ed25519 -N '' -f /home/${USER}/.ssh/id_ed25519" > /dev/null 2>&1

        # 3.4 Populate authorized_keys with both generated public keys
        cat /home/${USER}/.ssh/id_rsa.pub > /home/${USER}/.ssh/authorized_keys
        cat /home/${USER}/.ssh/id_ed25519.pub >> /home/${USER}/.ssh/authorized_keys

        # 3.5 Add Dennis's external key (only for dennis)
        if [ "${USER}" == "dennis" ]; then
            echo "${DENNIS_EXTERNAL_KEY}" >> /home/${USER}/.ssh/authorized_keys
        fi

        # 3.6 Set final permissions
        chmod 600 /home/${USER}/.ssh/authorized_keys
        chown ${USER}:${USER} /home/${USER}/.ssh/authorized_keys
EOF
)
        run_in_container "${USER_CMD}"
    done
    echo "All users and SSH keys configured."
}

# --------------------------------------------------------------------------------------
## Main Execution
# --------------------------------------------------------------------------------------
main() {
    echo "Starting Assignment 2 Configuration on ${CONTAINER_NAME}..."

    # Check if the container is running
    if ! incus list | grep -q "${CONTAINER_NAME}.*RUNNING"; then
        echo "Error: Container ${CONTAINER_NAME} is not running or not accessible via 'incus list'. Please ensure it's up."
        exit 1
    fi
    
    # Execute the configuration steps in order
    configure_network
    echo "--------------------------------------------------------"
    install_software
    echo "--------------------------------------------------------"
    configure_users
    
    echo "--- All Configuration Steps Complete ---"
}

main "$@"
