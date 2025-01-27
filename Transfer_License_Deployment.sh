#!/bin/bash

# Prompt for login method
echo "======================================="
echo "Azure VM SSH Login Script"
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
license_file="$local_dir$(grep "license_file" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')"
deployment_file="$local_dir$(grep "deployment_file" $source_config_file | cut -d'=' -f2 | tr -d '[:space:]')"

# Debugging output to verify the values from config.cfg
echo "License file path: $license_file"
echo "Deployment file path: $deployment_file"

# Validate file paths
if [[ ! -f "$license_file" || ! -f "$deployment_file" ]]; then
    echo "License or deployment file does not exist. Exiting."
    exit 1
fi

# Loop through the provided VM IPs and transfer files
IFS=',' read -r -a ips <<< "$vm_ips"

for ip in "${ips[@]}"; do
    echo "Transferring license and deployment files to $ip..."

    # Transfer license and deployment files
    if [ "$choice" -eq 1 ]; then
        sshpass -p "$password" scp "$license_file" "$deployment_file" "$username@$ip:$remote_dir" > /dev/null 2>&1
    elif [ "$choice" -eq 2 ]; then
        scp -i "$private_key_path" "$license_file" "$deployment_file" "$username@$ip:$remote_dir" > /dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        echo "Files successfully transferred to $ip."
    else
        echo "Error occurred while transferring files to $ip."
    fi
done

