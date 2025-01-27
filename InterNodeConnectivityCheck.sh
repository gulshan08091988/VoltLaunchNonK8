#!/bin/bash

# Prompt for login method
echo "======================================="
echo "Azure VM SSH Login Script - VoltDB Connectivity Check"
echo "======================================="
echo "Select an option:"
echo "1. Login directly with username and password"
echo "2. Login using SSH key"
read -p "Enter your choice (1 or 2): " choice

# Gather necessary input based on the choice
if [ "$choice" -eq 1 ]; then
    read -p "Enter the username for SSH login: " username
    read -p "Enter the public IP addresses of the VMs (comma separated): " vm_ips
    read -s -p "Enter the SSH password: " password
    echo ""
elif [ "$choice" -eq 2 ]; then
    read -p "Enter the username for SSH login: " username
    read -p "Enter the public IP addresses of the VMs (comma separated): " vm_ips
    read -p "Enter the path to the SSH private key: " private_key_path
    echo ""
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Define file paths based on your config file
source_config_file="config.cfg"
hosts=$(grep "hosts" $source_config_file |cut -d'=' -f2 | tr -d '[:space:]' | tr -d '%"')

# Read all hosts into an array
IFS=',' read -r -a config_hosts <<< "$hosts"

# Function to check SSH connectivity
check_connectivity() {
    local ip=$1
    local user=$2
    local pass=$3
    local key=$4
    local choice=$5

    if [ "$choice" -eq 1 ]; then
        sshpass -p "$pass" ssh -o ConnectTimeout=10 -q "$user@$ip" "exit" &>/dev/null
    elif [ "$choice" -eq 2 ]; then
        ssh -i "$key" -o ConnectTimeout=10 -q "$user@$ip" "exit" &>/dev/null
    fi

    return $?
}

# Loop through the provided VM IPs
IFS=',' read -r -a ips <<< "$vm_ips"

for ip in "${ips[@]}"; do
    # Check connectivity for the current VM
    echo "Checking connectivity for $ip..."
    if ! check_connectivity "$ip" "$username" "$password" "$private_key_path" "$choice"; then
        echo "Connectivity check failed for $ip. Skipping..."
        continue
    fi

    # SSH into the VM to get the local IP
    if [ "$choice" -eq 1 ]; then
        local_ip=$(sshpass -p "$password" ssh -q "$username@$ip" "hostname -i")
    elif [ "$choice" -eq 2 ]; then
        local_ip=$(ssh -i "$private_key_path" -q "$username@$ip" "hostname -i")
    fi

    echo "Local IP on $ip: $local_ip"

    # Compare the local IP with other hosts in the config file
    for host in "${config_hosts[@]}"; do
        if [ "$local_ip" != "$host" ]; then
            echo "Pinging $host from $local_ip..."
            if [ "$choice" -eq 1 ]; then
                sshpass -p "$password" ssh -q "$username@$ip" "ping -c 4 $host" &>/dev/null
            elif [ "$choice" -eq 2 ]; then
                ssh -i "$private_key_path" -q "$username@$ip" "ping -c 4 $host" &>/dev/null
            fi

            if [ $? -eq 0 ]; then
                echo "Ping to $host successful from $local_ip."
            else
                echo "Ping to $host failed from $local_ip."
            fi
        fi
    done
done

