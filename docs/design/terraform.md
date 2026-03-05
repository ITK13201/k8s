# Terraform 設計（Proxmox VE）

## Provider

`bpg/proxmox`（v0.97.1 以降）を使用する。
`telmate/proxmox` より活発にメンテナンスされており、Cloud-Init や最新 API への対応が充実している。

```hcl
# terraform/providers.tf
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint  # 例: https://192.168.x.x:8006/
  username = var.proxmox_username  # 例: root@pam
  password = var.proxmox_password
  insecure = true                  # 自己署名証明書の場合
}
```

## VM プロビジョニング方式

1. Rocky Linux 9 Cloud ImageをProxmoxにダウンロード（`proxmox_virtual_environment_download_file`）
2. ダウンロードしたイメージからTemplate VMを作成（`template = true`）
3. Template VMをクローンしてコントロールプレーン・ワーカーを起動（`clone`ブロック）
4. Cloud-Initで初期設定（ユーザー・SSH鍵・静的IP）を適用

CentOS Stream 9ではなく**Rocky Linux 9**を使用する（クラウドイメージが安定して提供されているため）。

## ファイル構成と責務

| ファイル | 責務 |
|---------|------|
| `providers.tf` | Provider 設定 |
| `variables.tf` | 変数定義 |
| `outputs.tf` | VM の IP アドレスを出力（Ansible inventory 生成に使用） |
| `template.tf` | Rocky Linux 9 テンプレート VM の作成 |
| `cloud_init.tf` | Cloud-Init 設定ファイルのアップロード |
| `control_plane.tf` | コントロールプレーン VM（テンプレートをクローン） |
| `workers.tf` | ワーカー VM（`count` でスケール） |
| `terraform.tfvars.example` | 変数サンプル（実際の `.tfvars` は gitignore） |

---

## Cloud-Init テンプレートの作成

### 1. Rocky Linux 9 Cloud Image のダウンロード

```hcl
# terraform/template.tf
resource "proxmox_virtual_environment_download_file" "rocky9_cloud_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  file_name    = "rocky9-genericcloud.qcow2"
}
```

### 2. テンプレート VM の作成

```hcl
# terraform/template.tf（続き）
resource "proxmox_virtual_environment_vm" "rocky9_template" {
  name      = "rocky9-template"
  node_name = var.proxmox_node
  vm_id     = 9000
  template  = true          # テンプレートとして保存
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

  serial_device {}   # コンソールアクセス用
}
```

---

## Cloud-Init 設定ファイル

### user-data（共通）

`qemu-guest-agent`のインストールが必須（TerraformがIPを取得するために使用）。

```hcl
# terraform/cloud_init.tf
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
```

> **注意**: `snippets` コンテンツタイプを使用するには、Proxmox の Datastore 設定で `snippets` コンテンツを有効にする必要がある。

---

## コントロールプレーン VM

```hcl
# terraform/control_plane.tf
resource "proxmox_virtual_environment_vm" "control_plane" {
  name      = "k8s-cp01"
  node_name = var.proxmox_node

  clone {
    vm_id = proxmox_virtual_environment_vm.rocky9_template.vm_id
    full  = true
  }

  agent {
    enabled    = true
    wait_for_ip = {
      ipv4 = true
    }
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
    datastore_id     = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    ip_config {
      ipv4 {
        address = "${var.control_plane_ip}/24"
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
```

---

## ワーカー VM

```hcl
# terraform/workers.tf
resource "proxmox_virtual_environment_vm" "workers" {
  count     = var.worker_count
  name      = "k8s-worker${format("%02d", count.index + 1)}"
  node_name = var.proxmox_node

  clone {
    vm_id = proxmox_virtual_environment_vm.rocky9_template.vm_id
    full  = true
  }

  agent {
    enabled    = true
    wait_for_ip = {
      ipv4 = true
    }
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

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.user_data.id

    ip_config {
      ipv4 {
        address = "${var.worker_ips[count.index]}/24"
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
```

---

## 変数設計

```hcl
# terraform/variables.tf
variable "proxmox_endpoint" { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_password" {
  type      = string
  sensitive = true
}
variable "proxmox_node"        { type = string }
variable "datastore_id"        { type = string; default = "local-lvm" }

variable "vm_user"             { type = string }
variable "ssh_public_key"      { type = string }

variable "gateway_ip"          { type = string }
variable "dns_server"          { type = string; default = "8.8.8.8" }

variable "control_plane_ip"    { type = string }
variable "control_plane_cpu_cores" { type = number; default = 4 }
variable "control_plane_memory_mb" { type = number; default = 8192 }
variable "control_plane_disk_gb"   { type = number; default = 50 }

variable "worker_count"        { type = number; default = 2 }
variable "worker_ips"          { type = list(string) }
variable "worker_cpu_cores"    { type = number; default = 4 }
variable "worker_memory_mb"    { type = number; default = 8192 }
variable "worker_disk_gb"      { type = number; default = 50 }
```

機密値（`proxmox_password`、`ssh_public_key`等）は`terraform.tfvars`（gitignore対象）に記載する。

## outputs.tf の設計

```hcl
# terraform/outputs.tf
output "control_plane_ip" {
  value = proxmox_virtual_environment_vm.control_plane.ipv4_addresses[1][0]
}

output "worker_ips" {
  value = [for vm in proxmox_virtual_environment_vm.workers : vm.ipv4_addresses[1][0]]
}
```

`terraform output -json` の結果をもとに `ansible/inventory/hosts.yml` を更新する。

## 主要コマンド

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# terraform.tfvars を編集

terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# IP の確認
terraform -chdir=terraform output -json
```

## Proxmox 事前設定（手動）

Terraform実行前にProxmox側で以下を行う。

1. `local`ストレージで`snippets`コンテンツを有効化
   - Proxmox UI → Datacenter → Storage → local → Edit → Contentに`Snippets`を追加
2. APIトークンまたは`root@pam`ユーザーの認証情報を用意
