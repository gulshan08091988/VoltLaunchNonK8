#!/bin/bash

while true; do
    echo "======================================="
    echo "VoltDB Deployment Management"
    echo "======================================="
    echo "Select an action:"
    echo "1. Perform Remote Prerequisite Checks"
    echo "2. Internode Connectivity Check"
    echo "3. Transfer and Extract VoltDB Binary"
    echo "4. Transfer License and Deployment Files"
    echo "5. Deploy VoltDB Cluster"
    echo "6. Exit"
    read -p "Enter your choice (1-6): " action

    case $action in
    1)
        echo "Performing prerequisite checks on remote servers..."
        ./Remote_Server_PreCheck.sh
        ;;
    2)
        echo "Performing Inter Node Communication..."
        ./InterNodeConnectivityCheck.sh
        ;;
    3)
        echo "Transferring and extracting VoltDB binary on remote servers..."
        ./Transfer_and_Extract_VoltDB1.sh
        ;;
    4)
        echo "Transferring license and deployment files to remote servers..."
        ./Transfer_License_Deployment.sh
        ;;
    5)
        echo "Deploying VoltDB cluster on remote servers..."
        ./Deploy_VoltDB.sh
        ;;
    6)
        echo "Exiting. Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice. Please select a valid option."
        ;;
    esac

    # Prompt to continue or exit
    echo
    read -p "Press Enter to return to the menu or type 'exit' to quit: " continue_choice
    if [[ "$continue_choice" == "exit" ]]; then
        echo "Exiting. Goodbye!"
        exit 0
    fi
done

