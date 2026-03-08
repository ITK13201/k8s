# Proxmox connection
variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint (e.g. https://192.168.1.100:8006/)"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox VE username (e.g. root@pam)"
}

variable "proxmox_password" {
  type        = string
  sensitive   = true
  description = "Proxmox VE password"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox VE node name"
}

# Storage
variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Proxmox datastore ID for VM disks"
}

variable "proxmox_ssh_private_key_path" {
  type        = string
  description = "Path to SSH private key for Proxmox host access"
}

# VM user
variable "vm_user" {
  type        = string
  description = "OS user to create on VMs via cloud-init"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to inject into VMs"
}

# Network
variable "gateway_ip" {
  type        = string
  description = "Default gateway IP"
}

variable "dns_servers" {
  type        = list(string)
  default     = ["8.8.8.8", "192.168.1.1"]
  description = "DNS server IPs (in priority order)"
}

# Control plane
variable "control_plane_ip" {
  type        = string
  description = "Static IP for control plane VM in CIDR notation (e.g. 192.168.1.10/24)"
}

variable "control_plane_cpu_cores" {
  type    = number
  default = 2
}

variable "control_plane_memory_mb" {
  type    = number
  default = 8192
}

variable "control_plane_disk_gb" {
  type    = number
  default = 30
}

# Worker
variable "worker_count" {
  type    = number
  default = 1
}

variable "worker_ips" {
  type        = list(string)
  description = "Static IPs for worker VMs in CIDR notation (e.g. [\"192.168.1.11/24\"])"
}

variable "worker_cpu_cores" {
  type    = number
  default = 10
}

variable "worker_memory_mb" {
  type    = number
  default = 32768
}

variable "worker_disk_gb" {
  type    = number
  default = 150
}

variable "worker_hdd_storage_by_id" {
  type        = string
  description = "by-id name of the storage HDD for disk passthrough (under /dev/disk/by-id/)"
}

variable "worker_hdd_backup_by_id" {
  type        = string
  description = "by-id name of the backup HDD for disk passthrough (under /dev/disk/by-id/)"
}
