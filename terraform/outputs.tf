output "control_plane_ip" {
  description = "Control plane VM IP address"
  value       = proxmox_virtual_environment_vm.control_plane.ipv4_addresses[1][0]
}

output "worker_ips" {
  description = "Worker VM IP addresses"
  value       = [for vm in proxmox_virtual_environment_vm.workers : vm.ipv4_addresses[1][0]]
}
