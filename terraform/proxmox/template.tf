resource "proxmox_virtual_environment_download_file" "rocky9_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  file_name    = "rocky9-genericcloud.qcow2"
}

resource "proxmox_virtual_environment_vm" "rocky9_template" {
  name      = "rocky9-template"
  node_name = var.proxmox_node
  vm_id     = 9000
  template  = true
  started   = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = proxmox_virtual_environment_download_file.rocky9_cloud_image.id
    interface    = "scsi0"
    size         = 20
    discard      = "on"
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
