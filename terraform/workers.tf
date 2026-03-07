resource "proxmox_virtual_environment_vm" "workers" {
  count     = var.worker_count
  name      = "k8s-worker${format("%02d", count.index + 1)}"
  node_name = var.proxmox_node

  clone {
    vm_id   = proxmox_virtual_environment_vm.rocky9_template.vm_id
    full    = true
    retries = 3
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.worker_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.worker_disk_gb
    discard      = "on"
  }

  disk {
    datastore_id      = ""
    path_in_datastore = "/dev/disk/by-id/${var.worker_hdd_storage_by_id}"
    file_format       = "raw"
    interface         = "scsi1"
  }

  disk {
    datastore_id      = ""
    path_in_datastore = "/dev/disk/by-id/${var.worker_hdd_backup_by_id}"
    file_format       = "raw"
    interface         = "scsi2"
  }

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    ip_config {
      ipv4 {
        address = var.worker_ips[count.index]
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
