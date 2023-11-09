#!/bin/bash

# This script toggles IOMMU on or off and assists with setting up GPU passthrough.
# It modifies the GRUB configuration for IOMMU and prepares the system for GPU passthrough.
# The script is intended for experienced users and should be used with caution.
# Author: Michael Agu
# Date: Nov 9, 2023
# GitHub: https://github.com/openmoto/proxmox_scripts
# Usage: ./toggle_iommu.sh


# Usage:
# - To enable/disable IOMMU or check the status, run:
#   sudo ./this_script.sh on
#   sudo ./this_script.sh off
#   sudo ./this_script.sh status
#
# - To set up GPU passthrough, run:
#   sudo ./this_script.sh passthrough
#   Follow the prompts to select the GPU and generate a configuration file.
#   Review the generated configuration file, then run the script again to apply changes.

CONFIG_FILE="/etc/vfio-passthrough.conf"
GRUB_CONFIG="/etc/default/grub"
GRUB_BAK="/etc/default/grub.bak"

# Function to update GRUB and optionally reboot
update_grub_and_reboot() {
    if update-grub; then
        echo "GRUB updated successfully."
        read -p "Reboot now to apply changes? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Rebooting in 5 seconds..."
            sleep 5
            reboot
        else
            echo "Reboot cancelled. Remember to reboot manually to apply changes."
        fi
    else
        echo "Failed to update GRUB. Please check the error message above."
    fi
}

# Function to toggle IOMMU
toggle_iommu() {
    local action=$1
    local iommu_status=$(grep -c "intel_iommu=on" "$GRUB_CONFIG")
    case $action in
        on)
            if [[ $iommu_status -eq 0 ]]; then
                echo "Enabling IOMMU..."
                cp "$GRUB_CONFIG" "$GRUB_BAK"
                sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=on iommu=pt"/' "$GRUB_CONFIG"
                update_grub_and_reboot
            else
                echo "IOMMU is already enabled."
            fi
            ;;
        off)
            if [[ $iommu_status -eq 1 ]]; then
                echo "Disabling IOMMU..."
                cp "$GRUB_CONFIG" "$GRUB_BAK"
                sed -i 's/ intel_iommu=on iommu=pt//g' "$GRUB_CONFIG"
                update_grub_and_reboot
            else
                echo "IOMMU is already disabled."
            fi
            ;;
        status)
            if [[ $iommu_status -eq 1 ]]; then
                echo "IOMMU is enabled."
            else
                echo "IOMMU is disabled."
            fi
            ;;
        *)
            echo "Invalid action for IOMMU toggling. Use 'on', 'off', or 'status'."
            exit 1
            ;;
    esac
}

# Function to set up GPU passthrough
setup_gpu_passthrough() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration file found. Proceeding with GPU passthrough setup..."
        source "$CONFIG_FILE"
        
        # Add VFIO modules to /etc/modules
        echo "vfio" >> /etc/modules
        echo "vfio_iommu_type1" >> /etc/modules
        echo "vfio_pci" >> /etc/modules
        echo "vfio_virqfd" >> /etc/modules

        # Create VFIO configurations
        echo "options vfio-pci ids=$VENDOR_ID:$DEVICE_ID disable_vga=1" > /etc/modprobe.d/vfio.conf

        # Blacklist GPU drivers
        echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
        echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
        echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
        echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
        echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf

        # Update initramfs
        update-initramfs -u -k all

        echo "The changes have been applied. Please reboot your system for them to take effect."
    else
        echo "No configuration file found. Detecting GPUs..."
        lspci -nn | grep -i --color 'vga\|3d\|2d'
        echo "Please enter the GPU's Vendor:Device ID (e.g., 10de:1b80) to use for passthrough:"
        read -p "ID: " GPU_ID
        VENDOR_ID=$(echo $GPU_ID | cut -d ':' -f 1)
        DEVICE_ID=$(echo $GPU_ID | cut -d ':' -f 2)

        echo "Generating configuration file..."
        echo "VENDOR_ID=$VENDOR_ID" > "$CONFIG_FILE"
        echo "DEVICE_ID=$DEVICE_ID" >> "$CONFIG_FILE"
        echo "Configuration file generated at $CONFIG_FILE"
        echo "Please review the configuration file and rerun this script to apply changes."
    fi
}

# Main script logic
case $1 in
    on|off|status)
        toggle_iommu $1
        ;;
    passthrough)
        setup_gpu_passthrough
        ;;
    *)
        echo "Invalid argument. Use 'on', 'off', 'status' for IOMMU or 'passthrough' for GPU passthrough."
        exit 1
        ;;
esac