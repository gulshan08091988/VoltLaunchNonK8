#!/bin/bash

# Function to perform prerequisite checks and fix issues on the remote server
prerequisite_checks_and_fix_remote() {
  vm_ip=$1
  username=$2
  auth_method=$3
  password_or_key=$4

  # Define the remote check-and-fix script as a heredoc
  remote_script=$(cat <<'EOF'
#!/bin/bash
echo "VoltDB Prerequisite Check and Fix Script"
echo "========================================"

# Function to check and fix Transparent Huge Pages (THP)
check_and_fix_thp() {
  echo "Checking Transparent Huge Pages (THP)..."
  if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    thp_enabled=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
    if [[ "$thp_enabled" == *"[always]"* ]]; then
      echo "THP is enabled. Disabling it..."
      sudo bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
      sudo bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
      echo "THP disabled for the current session."

      # Add commands to disable THP on reboot
      if [ ! -f /etc/rc.local ]; then
        echo "Creating /etc/rc.local..."
        sudo bash -c 'echo -e "#!/bin/bash\nexit 0" > /etc/rc.local'
        sudo chmod +x /etc/rc.local
      fi

      if ! grep -q 'transparent_hugepage' /etc/rc.local; then
        echo "Adding commands to /etc/rc.local to disable THP on reboot..."
        sudo tee -a /etc/rc.local > /dev/null <<EOL
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOL
      fi
      echo "THP will remain disabled after reboot. ✅"
    else
      echo "THP is already disabled. ✅"
    fi
  else
    echo "THP configuration file not found. Skipping check."
  fi
}

# Function to check and fix Java installation
check_and_fix_java() {
  echo "Checking Java installation..."
  
  if java -version >/dev/null 2>&1; then
    # Get the installed Java version
    java_version=$(java -version 2>&1 | grep -i version | awk -F '"' '{print $2}')
    
    # Extract major version number (11, 17, or 21)
    java_major_version=$(echo $java_version | cut -d'.' -f1)

    # Check if the Java version is one of the allowed versions (11, 17, or 21)
    if [[ "$java_major_version" == "11" || "$java_major_version" == "17" || "$java_major_version" == "21" ]]; then
      echo "Java is installed (version: $java_version). ✅"
    else
      echo "Java version $java_version is not supported. Installing Java 11..."
      sudo apt update && sudo apt install -y openjdk-11-jdk
      echo "Java 11 installed. ✅"
    fi
  else
    echo "Java is not installed. Installing Java 11..."
    sudo apt update && sudo apt install -y openjdk-11-jdk
    echo "Java 11 installed. ✅"
  fi
}

# Function to check and fix Python installation
check_and_fix_python() {
  echo "Checking Python installation..."
  
  if python3 --version >/dev/null 2>&1; then
    # Get the installed Python version
    python_version=$(python3 --version | awk '{print $2}')
    
    # Extract the major and minor version (e.g., 3.9, 3.10)
    python_major_minor_version=$(echo $python_version | cut -d'.' -f1,2)
    
    # Compare with required version (3.9 or later)
    if [[ "$(echo -e "3.9\n$python_major_minor_version" | sort -V | head -n1)" == "3.9" ]]; then
      echo "Python is installed (version: $python_version). ✅"
    else
      echo "Python version $python_version is older than 3.9. Installing Python 3.9..."
      sudo apt update && sudo apt install -y python3.9 python3-pip
      echo "Python 3.9 installed. ✅"
    fi
  else
    echo "Python is not installed. Installing Python 3.9..."
    sudo apt update && sudo apt install -y python3.9 python3-pip
    echo "Python 3.9 installed. ✅"
  fi
}

# Function to check and fix TCP Segmentation Offload (TSO)
check_and_fix_tcp_segmentation() {
  echo "Checking TCP Segmentation Offload (TSO)..."
  for iface in $(ls /sys/class/net); do
    tso_status=$(ethtool -k "$iface" 2>/dev/null | grep tcp-segmentation-offload | awk '{print $2}')
    if [ "$tso_status" == "on" ]; then
      echo "TSO is enabled on interface $iface. Disabling it..."
      sudo ethtool -K "$iface" tso off
      echo "TSO disabled on interface $iface. ✅"
    else
      echo "TSO is already disabled on interface $iface. ✅"
    fi
  done
}

# Function to check and fix ulimit values
check_and_fix_ulimit() {
  echo "Checking ulimit values..."
  max_open_files=$(ulimit -n)
  max_processes=$(ulimit -u)

  if [ "$max_open_files" -lt 65536 ]; then
    echo "Open file descriptors limit is $max_open_files. Increasing to 65536..."
    sudo bash -c 'ulimit -n 65536'
    echo "Open file descriptors limit increased to 65536. ✅"
  else
    echo "Open file descriptors limit is sufficient ($max_open_files). ✅"
  fi

  if [ "$max_processes" -lt 65536 ]; then
    echo "Max user processes limit is $max_processes. Increasing to 65536..."
    sudo bash -c 'ulimit -u 65536'
    echo "Max user processes limit increased to 65536. ✅"
  else
    echo "Max user processes limit is sufficient ($max_processes). ✅"
  fi
}

check_and_fix_latency_config() {
  echo "Checking latency configuration..."
  echo "Verifying CPU frequency scaling governor..."
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    scaling_dir="$cpu/cpufreq"

    # Check if the scaling governor directory exists
    if [ -d "$scaling_dir" ]; then
      governor=$(cat "$scaling_dir/scaling_governor" 2>/dev/null)
      if [ "$governor" != "performance" ]; then
        echo "CPU $cpu is set to $governor. Setting it to 'performance'..."
        sudo bash -c "echo performance > $scaling_dir/scaling_governor"
        echo "CPU $cpu is now set to performance. ✅"
      else
        echo "CPU $cpu is already set to performance. ✅"
      fi
    else
      echo "CPU $cpu does not support frequency scaling or the scaling governor is not available. Skipping this CPU. ❌"
    fi
  done
}

# Check if VOLTDB_OPTS is set for JVM statistics
check_and_disable_jvm_stats() {
  echo "Checking if JVM stats are disabled..."

  # Check if VOLTDB_OPTS is not set or does not have the required JVM stats disabling flag
  if [ -z "$VOLTDB_OPTS" ]; then
    echo "Warning: VOLTDB_OPTS is not set."
    echo "You should run the following command before starting VoltDB:"
    echo "export VOLTDB_OPTS='-XX:+PerfDisableSharedMem'"
    export VOLTDB_OPTS='-XX:+PerfDisableSharedMem'
	echo "export VOLTDB_OPTS='-XX:+PerfDisableSharedMem'" > /home/voltdb/.bashrc
    echo "VOLTDB_OPTS has been set to disable JVM stats. ✅"
  elif [[ "$VOLTDB_OPTS" != *"-XX:+PerfDisableSharedMem"* ]]; then
    echo "Warning: VOLTDB_OPTS is not set to disable JVM stats."
    echo "Current VOLTDB_OPTS: $VOLTDB_OPTS"
    echo "You should add '-XX:+PerfDisableSharedMem' to VOLTDB_OPTS."
    export VOLTDB_OPTS="$VOLTDB_OPTS -XX:+PerfDisableSharedMem"
    echo "VOLTDB_OPTS has been updated to disable JVM stats. ✅"
  else
    echo "JVM stats are disabled. ✅"
  fi
}

# Function to check if specific ports are in use
check_ports_in_use() {
  echo "Checking if ports 21212, 21211, 8080, 3021, 5555, 7181 are in use..."

  # Get the list of in-use ports and store in a variable
  in_use_ports=$(ss -tuln | grep -E '(:21212|:21211|:8080|:3021|:5555|:7181)')

  if [ -n "$in_use_ports" ]; then
    echo "The following ports are in use: $in_use_ports ❌"
  else
    echo "None of the specified ports are in use. ✅"
  fi
}

check_and_fix_thp
check_and_fix_java
check_and_fix_python
check_and_fix_tcp_segmentation
check_and_fix_ulimit
check_and_fix_latency_config
check_and_disable_jvm_stats
check_ports_in_use

echo "========================================"
echo "Prerequisite checks and fixes completed."
EOF
)

  # Execute the remote script based on the authentication method
  echo "Performing prerequisite check and fix on remote VM: $vm_ip"
  if [ "$auth_method" == "password" ]; then
    sshpass -p "$password_or_key" ssh -o StrictHostKeyChecking=no "$username@$vm_ip" "bash -s" <<< "$remote_script"
  else
    ssh -i "$password_or_key" -o StrictHostKeyChecking=no "$username@$vm_ip" "bash -s" <<< "$remote_script"
  fi
}

# Menu for user to select login type
echo "VoltDB Remote Prerequisite Check and Fix Script"
echo "==============================================="
echo "Select an option:"
echo "1. Login directly with username and password"
echo "2. Login using SSH key"
read -p "Enter your choice (1 or 2): " choice

if [ "$choice" -eq 1 ]; then
  echo "You have selected to log in via SSH with password authentication."
  read -p "Enter the Public IP Addresses of the VMs (comma separated): " ip_addresses
  read -p "Enter the Username: " username
  read -sp "Enter the Password: " password
  echo

  # Loop through all IP addresses
  IFS=',' read -r -a ips <<< "$ip_addresses"
  for ip in "${ips[@]}"; do
    prerequisite_checks_and_fix_remote "$ip" "$username" "password" "$password"
  done

elif [ "$choice" -eq 2 ]; then
  echo "You have selected to log in via SSH with key authentication."
  read -p "Enter the Public IP Addresses of the VMs (comma separated): " ip_addresses
  read -p "Enter the Username: " username
  read -p "Enter the Path to Your SSH Private Key: " ssh_key

  # Loop through all IP addresses
  IFS=',' read -r -a ips <<< "$ip_addresses"
  for ip in "${ips[@]}"; do
    prerequisite_checks_and_fix_remote "$ip" "$username" "key" "$ssh_key"
  done
else
  echo "Invalid choice. Exiting."
  exit 1
fi

echo "Script execution completed."

