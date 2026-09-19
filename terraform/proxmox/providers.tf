terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
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
    # 1Password SSH Agent 経由で認証する（秘密鍵ファイルは扱わない）。
    # agent_socket は SSH_AUTH_SOCK に依存せず明示する。
    agent        = true
    agent_socket = pathexpand("~/.1password/agent.sock")
    username     = "root"
  }
}
