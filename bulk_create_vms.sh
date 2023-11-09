#!/bin/bash

# Script to create bulk VMs for an RKE2 cluster on Proxmox based on the scripts below:
# https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/RKE2/rke2.sh
# https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/Longhorn/longhorn-RKE2.sh
# Ensure to update the following as per your environment before running the script:
# Prerequisites:
# 1. You have a vm template created. 
# 2. You have reserverd IPs on your firewall for the Mac addresses you are using
# 3. If you have your ssh public key saved in the VM template cloudinit, you should be able to login once they're online
# - VMIDs: Specify the range of VM IDs to stop and delete.
# - vms: An associative array that contains VM names as keys and "VMID MAC_ADDRESS DISK_SIZE" as values.
# - TEMPLATE_VM_ID: Set this to the VM ID of your Proxmox template.
# - VM_STORAGE: Set this to your storage ID where the VM disks will reside.
# - Update your bridge=vmbr1,tag=10 to the correct proxmox bridge and vlan tag for your home lab if any.
#
# Author: Michael Agu
# Date: Nov 9, 2023
# GitHub: https://github.com/openmoto/proxmox_scripts
# Usage: ./create-rke2-vms.sh

# Stops and deletes existing VMs in the specified range.
for VMID in {2001..2010}; do
  qm stop $VMID && qm destroy $VMID
done

# VM specifications in an associative array.
declare -A vms=(
  #["VM_NAME"]="VMID MAC_ADDRESS DISK_SIZE"
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

TEMPLATE_VM_ID="5000" # Update with your template VM ID
VM_STORAGE="local-lvm" # Update with your VM storage ID

# Create VMs from the template and configure them.
for vm_name in "${!vms[@]}"; do
  read -r vm_id mac_address disk_size <<< "${vms[$vm_name]}"
  echo "Creating VM $vm_name with ID $vm_id"
  qm clone $TEMPLATE_VM_ID $vm_id --name $vm_name --full true
  qm set $vm_id --net0 model=virtio,bridge=vmbr1,tag=10,macaddr=$mac_address
  qm resize $vm_id scsi0 ${disk_size}
  qm start $vm_id
done

echo "VM creation process completed."
