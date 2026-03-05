resource "proxmox_virtual_environment_vm" "control_plane" {
  name      = "k8s-cp01"
  node_name = var.proxmox_node

  clone {
    vm_id = proxmox_virtual_environment_vm.rocky9_template.vm_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.control_plane_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.control_plane_memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.control_plane_disk_gb
    discard      = "on"
  }

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    ip_config {
      ipv4 {
        address = var.control_plane_ip
        gateway = var.gateway_ip
      }
    }

    dns {
      servers = [var.dns_server]
    }
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}
}
