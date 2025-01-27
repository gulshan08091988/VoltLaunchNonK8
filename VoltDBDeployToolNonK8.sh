#!/bin/bash

echo "======================================="
echo "VoltDB Deployment Management"
echo "======================================="
echo "Select an action:"
echo "1. Perform Remote Prerequisite Checks"
echo "2. Transfer and Extract VoltDB Binary"
echo "3. Transfer License and Deployment Files"
echo "4. Deploy VoltDB Cluster"
echo "5. Exit"
read -p "Enter your choice (1-5): " action

case $action in
1)
    echo "Performing prerequisite checks on remote servers..."
    ./Remote_Server_PreCheck.sh
    ;;
2)
    echo "Transferring and extracting VoltDB binary on remote servers..."
    ./Transfer_and_Extract_VoltDB.sh
    ;;
3)
    echo "Transferring license and deployment files to remote servers..."
    ./Transfer_License_Deployment.sh
    ;;
4)
    echo "Deploying VoltDB cluster on remote servers..."
    ./Deploy_VoltDB.sh
    ;;
5)
    echo "Exiting. Goodbye!"
    exit 0
    ;;
*)
    echo "Invalid choice. Please select a valid option."
    ;;
esac
