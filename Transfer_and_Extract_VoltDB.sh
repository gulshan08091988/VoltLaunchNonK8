#!/bin/bash

# Prompt for login method
echo "======================================="
echo "Azure VM SSH Login Script - VoltDB Binary Transfer"
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
local_dir=$(grep "local_dir" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')
remote_dir=$(grep "remote_dir" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')
voltdb_binary_name="$local_dir$(grep "voltdb_binary_name" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')"

# Debugging output to verify the values from config.cfg
echo "VoltDB binary file path: $voltdb_binary_name"

# Validate file path
if [[ ! -f "$voltdb_binary_name" ]]; then
    echo "VoltDB binary file does not exist. Exiting."
    exit 1
fi

# Loop through the provided VM IPs and transfer and extract VoltDB binary
IFS=',' read -r -a ips <<< "$vm_ips"

for ip in "${ips[@]}"; do
    echo "Transferring and extracting VoltDB binary to $ip..."

    # Transfer and extract in one command
    if [ "$choice" -eq 1 ]; then
        # Using sshpass to automate both steps
        sshpass -p "$password" scp "$voltdb_binary_name" "$username@$ip:$remote_dir" && \
        sshpass -p "$password" ssh "$username@$ip" "tar -xzf $remote_dir/$(basename $voltdb_binary_name) -C $remote_dir"
    elif [ "$choice" -eq 2 ]; then
        # Using SSH key for both steps
        scp -i "$private_key_path" "$voltdb_binary_name" "$username@$ip:$remote_dir" && \
        ssh -i "$private_key_path" "$username@$ip" "tar -xzf $remote_dir/$(basename $voltdb_binary_name) -C $remote_dir"
    fi

    if [ $? -eq 0 ]; then
        echo "VoltDB binary successfully transferred and extracted on $ip."
    else
        echo "Error occurred while transferring or extracting VoltDB binary on $ip."
    fi
done

