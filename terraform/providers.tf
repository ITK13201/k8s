terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.98"
    }
  }

  # 値は backend.hcl で指定する（terraform init -backend-config=backend.hcl）
  backend "s3" {}
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true

  ssh {
    agent       = false
    username    = "root"
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}
