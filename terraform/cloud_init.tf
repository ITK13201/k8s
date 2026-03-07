resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "k8s-user-data.yaml"
    data      = <<-EOF
      #cloud-config
      users:
        - name: ${var.vm_user}
          groups: wheel
          sudo: ALL=(ALL) NOPASSWD:ALL
          shell: /bin/bash
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
      timezone: Asia/Tokyo
    EOF
  }
}
