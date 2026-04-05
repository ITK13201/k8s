# 既存バケットは terraform import で取り込む:
#   terraform import cloudflare_r2_bucket.tf_state "<ACCOUNT_ID>/tf-state-k8s/default"
resource "cloudflare_r2_bucket" "tf_state" {
  provider = cloudflare.r2

  account_id = var.cloudflare_account_id
  name       = "tf-state-k8s"
  location   = "apac"
}
