#!/bin/bash

# Description: This script automates the process of creating a set of VMs for an RKE2 cluster based on https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/RKE2/rke2.sh
# and
# https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/Longhorn/longhorn-RKE2.sh
# It stops and deletes existing VMs in the specified range and then creates new VMs based on a template.
# This is handy for testing if you're constantly recreating VMs for testing
# Author: Michael Agu
# Date: Nov 9, 2023
# GitHub: https://github.com/openmoto/proxmox_scripts
# Usage: ./create-rke2-vms.sh

# Stops and deletes existing VMs in the range 2001 to 2010.
for VMID in {2001..2010}; do
  qm stop $VMID && qm destroy $VMID
done

# VM specifications are defined in an associative array.
# Each VM has a name, VM ID, MAC address, and disk size.
declare -A vms=(
  ["rke2-a-01"]="2001 F6:D4:71:15:CB:79 10G"
  ["rke2-m-01"]="2002 76:41:2F:64:D6:1E 10G"
  ["rke2-m-02"]="2003 D6:69:D9:4F:21:5C 10G"
  ["rke2-m-03"]="2004 BE:26:0B:45:3C:94 10G"
  ["rke2-w-01"]="2005 0A:B8:38:A0:57:F5 10G"
  ["rke2-w-02"]="2006 76:C4:19:17:05:56 10G"
  ["rke2-w-03"]="2007 52:B7:02:32:19:0C 10G"
  ["rke2-s-01"]="2008 16:97:9E:3E:4A:49 250G"
  ["rke2-s-02"]="2009 0E:33:D9:FB:DF:B7 250G"
  ["rke2-s-03"]="2010 E6:F8:36:7E:38:96 250G"
)

TEMPLATE_VM_ID="5000" # Template VM ID used for cloning new VMs.
VM_STORAGE="local-lvm" # Storage ID to be used for VM disk.

# Loop through the VM specifications to create VMs.
for vm_name in "${!vms[@]}"; do
  # Parse VM ID, MAC address, and disk size from the associative array.
  read -r vm_id mac_address disk_size <<< "${vms[$vm_name]}"

  echo "Creating VM $vm_name with ID $vm_id"

  # Clone the VM from the template and set the VM name.
  qm clone $TEMPLATE_VM_ID $vm_id --name $vm_name --full true

  # Configure network settings: MAC address, bridge, and VLAN.
  qm set $vm_id --net0 model=virtio,bridge=vmbr1,tag=10,macaddr=$mac_address

  # Resize the VM's disk to the desired size.
  qm resize $vm_id scsi0 ${disk_size}
done

# The script ends here. All VMs should now be created with the specified configurations.
