#!/bin/bash

# Logfile for capturing the output
LOGFILE=upgrade_log.txt
exec > >(tee -a "$LOGFILE") 2>&1

# Function to check available disk space
check_disk_space() {
    echo "Checking disk space..."
    df -h | grep -E '^/dev/'
    read -p "Proceed with the upgrade? (y/n): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Upgrade aborted due to insufficient space."
        exit 1
    fi
}

# Function to clean up the APT cache and remove unnecessary packages
cleanup_system() {
    echo "Cleaning up system..."
    sudo apt-get autoremove -y
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    echo "System cleanup completed."
}

# Function to unhold packages if necessary
unhold_packages() {
    echo "Checking for held packages..."
    held_packages=$(dpkg --get-selections | grep hold)
    if [ -n "$held_packages" ]; then
        echo "The following packages are held: $held_packages"
        read -p "Do you want to unhold these packages? (y/n): " unhold_response
        if [[ "$unhold_response" =~ ^[Yy]$ ]]; then
            sudo apt-mark unhold $(echo "$held_packages" | awk '{print $1}')
            echo "Held packages have been unheld."
        else
            echo "Held packages remain unmodified."
        fi
    fi
}

# Function to remove third-party PPAs
remove_ppas() {
    echo "Removing third-party PPAs..."
    ppas=$(ls /etc/apt/sources.list.d/)
    if [ -n "$ppas" ]; then
        echo "The following PPAs will be removed: $ppas"
        read -p "Do you want to remove these PPAs? (y/n): " ppa_response
        if [[ "$ppa_response" =~ ^[Yy]$ ]]; then
            sudo rm -f /etc/apt/sources.list.d/*
            echo "Third-party PPAs have been removed."
        else
            echo "PPAs remain unchanged."
        fi
    else
        echo "No third-party PPAs found."
    fi
}

# Function to revert to the generic kernel (optional)
revert_kernel() {
    current_kernel=$(uname -r)
    if [[ ! "$current_kernel" =~ "generic" ]]; then
        read -p "You are not using a generic kernel. Would you like to switch to it? (y/n): " switch_kernel
        if [[ "$switch_kernel" =~ ^[Yy]$ ]]; then
            sudo apt install linux-image-generic -y
            echo "Reverted to the generic kernel."
        else
            echo "Kernel remains unchanged."
        fi
    fi
}

# Function to check if do-release-upgrade is installed
check_do_release_upgrade() {
    if ! command -v do-release-upgrade &>/dev/null; then
        echo "do-release-upgrade is not installed. Installing..."
        sudo apt install update-manager-core -y
    fi
}

# Function to upgrade the system
upgrade_system() {
    echo "Upgrading the system..."
    sudo apt update
    if ! sudo apt upgrade -y; then
        echo "APT upgrade failed. Exiting..."
        exit 1
    fi
    sudo apt dist-upgrade -y
    echo "System upgrade completed."
}

# Function to reboot if necessary
reboot_system() {
    read -p "Do you want to reboot now to complete the upgrade? (y/n): " reboot_response
    if [[ "$reboot_response" =~ ^[Yy]$ ]]; then
        echo "Rebooting system..."
        sudo reboot
    else
        echo "Reboot later to finalize the upgrade."
    fi
}

# Function to run do-release-upgrade
run_release_upgrade() {
    echo "Starting Ubuntu upgrade process..."
    sudo do-release-upgrade
}

# Main function to coordinate the upgrade process
main() {
    check_disk_space
    cleanup_system
    unhold_packages
    remove_ppas
    revert_kernel
    check_do_release_upgrade
    upgrade_system
    run_release_upgrade
    reboot_system
}

# Execute the main function
main
