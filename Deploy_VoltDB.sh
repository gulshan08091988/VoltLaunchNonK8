#!/bin/bash

# Prompt for login method
echo "======================================="
echo "Azure VM SSH Login Script - VoltDB Initialization"
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
remote_dir=$(grep "remote_dir" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')
voltdb_binary_name="$(grep "voltdb_binary_name" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')"
voltdb_dir_name="${voltdb_binary_name%.tar.gz}"
license_file=$(grep "license_file" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')
deployment_file=$(grep "deployment_file" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')
hosts=$(grep "hosts" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')

# Debugging output to verify the values from config.cfg
echo "VoltDB binary file path: $voltdb_dir_name"
echo "Hosts to start VoltDB on: $hosts"
echo "License file: $license_file"
echo "Deployment file: $deployment_file"

# Loop through the provided VM IPs and transfer, extract, and initialize VoltDB cluster
IFS=',' read -r -a ips <<< "$vm_ips"

for ip in "${ips[@]}"; do
    echo "Logging in to $ip and initializing VoltDB cluster..."

    # Login and validate the extracted VoltDB binary folder on remote server
    if [ "$choice" -eq 1 ]; then
        # Using sshpass for direct login with password (silent mode)
        sshpass -p "$password" ssh -q "$username@$ip" << EOF
            # Validate if the VoltDB binary folder exists on the remote server
            if [[ ! -d "$remote_dir/$voltdb_dir_name" ]]; then
                echo "Extracted VoltDB binary does not exist at $remote_dir/$voltdb_dir_name. Exiting."
                exit 1
            fi

            # Change directory to the extracted VoltDB binary folder
            cd "$remote_dir/$voltdb_dir_name" || { echo "Failed to cd into $remote_dir/$voltdb_dir_name"; exit 1; }

            # Initialize the VoltDB cluster
            bin/voltdb init --config=$remote_dir/$deployment_file --license=$remote_dir/$license_file --force

            # Start the VoltDB cluster in the background using the host information
            bin/voltdb start --host=$hosts --background
EOF
    elif [ "$choice" -eq 2 ]; then
        # Using SSH key for login (silent mode)
        ssh -i "$private_key_path" -q "$username@$ip" << EOF
            # Validate if the VoltDB binary folder exists on the remote server
            if [[ ! -d "$remote_dir/$voltdb_dir_name" ]]; then
                echo "Extracted VoltDB binary does not exist at $remote_dir/$voltdb_dir_name. Exiting."
                exit 1
            fi

            # Change directory to the extracted VoltDB binary folder
            cd "$remote_dir/$voltdb_dir_name" || { echo "Failed to cd into $remote_dir/$voltdb_dir_name"; exit 1; }

            # Initialize the VoltDB cluster
            bin/voltdb init --config=$deployment_file --license=$license_file --force

            # Start the VoltDB cluster in the background using the host information
            bin/voltdb start --host=$hosts --background
EOF
    fi

    if [ $? -eq 0 ]; then
        echo "VoltDB cluster initialization and start completed on $ip."
    else
        echo "Error occurred while initializing or starting VoltDB cluster on $ip."
    fi
done

