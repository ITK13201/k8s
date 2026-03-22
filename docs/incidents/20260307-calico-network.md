# インシデント: Calico ネットワーク障害による ArgoCD 起動失敗

- **発生日**: 2026-03-07
- **解決日**: 2026-03-07
- **影響範囲**: Kubernetes クラスタ全体（Proxmox VE 移行後の初回構築）
- **重大度**: High（クラスタ全機能停止）

---

## 症状

Proxmox VE 移行後に Ansible でクラスタを構築したところ、ArgoCD が起動しなかった。

```
# argocd-redis secret-init コンテナのログ
dial tcp 10.96.0.1:443: i/o timeout

# argocd-applicationset-controller のログ
fatal: unable to access 'https://github.com/ITK13201/k8s.git/':
Could not resolve host: github.com
```

---

## 原因

2 つの独立した設定ミスが重なっていた。

### 原因 1: pod CIDR と物理ネットワークの重複

| 項目 | 値 |
|------|-----|
| 旧 pod CIDR | `192.168.0.0/16` |
| 物理ネットワーク | `192.168.1.0/24` |
| 上流 DNS（ルーター） | `192.168.1.1` |

Calico の MASQUERADE ルールは「宛先が pod CIDR の**外**」のパケットにのみ適用される。
`192.168.1.1`（上流 DNS）が pod CIDR `192.168.0.0/16` の内側に含まれるため、
CoreDNS から上流 DNS へのパケットが MASQUERADE されず、Pod の IP アドレスのまま
ルーターに到達した。ルーターは Pod IP への返送経路を持たないため、DNS 応答が返らなかった。

```
CoreDNS (192.168.51.x) → 192.168.1.1:53
                                ↑
                 MASQUERADE スキップ（宛先が pod CIDR 内）
                 → ルーターが返送できず i/o timeout
```

### 原因 2: Calico ipipMode: Always と Proxmox ブリッジの非互換

Calico のデフォルト設定（`ipipMode: Always`）では、ノード間の Pod 通信に
IPIP トンネルインターフェース `tunl0` を使用する。
`tunl0` の外部ソース IP はトンネル専用の IP（`192.168.51.x` 等）となり、
物理 NIC の IP（`192.168.1.x`）とは異なる。

Proxmox の Linux ブリッジ（vmbr0）は `192.168.1.0/24` 外のソース IP を持つ
パケットを不正と判断してドロップするため、ノード間の Pod 通信が全断した。

```
worker01 tunl0 (src=192.168.51.0)
  → Proxmox vmbr0
  → ドロップ（192.168.1.0/24 外のソース IP）
  → API サーバー (10.96.0.1:443) に到達不可
```

---

## 調査手順

```bash
# 1. Pod 間疎通確認（cp01 → worker01 の Pod に ping）
kubectl exec -n argocd <pod> -- ping 10.244.51.x

# 2. IPIP パケットの追跡
# cp01 側で TX カウンタが増加するが worker01 の eth0 にパケットが届かないことを確認
ip -s link show tunl0
tcpdump -i eth0 proto 4  # IPIP パケット (proto 4) を監視

# 3. ルーティングテーブルの確認
ip route show | grep 10.244.51

# 4. CoreDNS のログ確認
kubectl logs -n kube-system -l k8s-app=kube-dns
# → read udp 192.168.51.x:port->192.168.1.1:53: i/o timeout

# 5. DNS 解決テスト（別 namespace で busybox を起動）
kubectl run dnstest --image=busybox:1.28 --restart=Never --rm -it \
  -- nslookup github.com
```

---

## 対処

### 対処 1: pod CIDR の変更（クラスタ再構築）

pod CIDR を物理ネットワークと重複しない範囲に変更した。
kubeadm の pod CIDR は初期化時にのみ指定可能なため、クラスタを再構築した。

```yaml
# ansible/inventory/group_vars/all.yml
k8s_pod_network_cidr: "10.244.0.0/16"  # 192.168.0.0/16 から変更
```

### 対処 2: Calico IPPool を CrossSubnet モードに変更

`ipipMode: CrossSubnet` では、同一 L2 サブネット内のノード間通信は
IPIP トンネルを使わず eth0 で直接ルーティングする。
cp01・worker01 は同一 L2（`192.168.1.0/24`）にあるため、Proxmox ブリッジを
正常に通過できる。

```bash
kubectl patch ippool default-ipv4-ippool \
  --type=merge \
  -p '{"spec":{"ipipMode":"CrossSubnet","natOutgoing":true}}'
```

適用後のルーティングテーブル（worker01）:

```
# 修正前
10.244.51.0/24 dev tunl0

# 修正後
10.244.51.0/24 via 192.168.1.200 dev eth0  ← 直接ルーティング
```

### 永続化

クラスタ再構築時に自動適用されるよう Ansible ロールに組み込んだ。

- `ansible/roles/k8s_control_plane/tasks/main.yml` — Calico 適用後に IPPool をパッチするタスクを追加
- `ansible/roles/k8s_control_plane/defaults/main.yml` — pod CIDR デフォルト値を `10.244.0.0/16` に更新

---

## 教訓

### pod CIDR の選定基準

pod CIDR は以下と重複しない範囲を選ぶこと。

| 用途 | 範囲 |
|------|------|
| 物理ネットワーク | `192.168.1.0/24` |
| Service（ClusterIP） | `10.96.0.0/12` |
| pod CIDR（現在） | `10.244.0.0/16` ✓ |

### Proxmox 上で Calico を使う場合の必須設定

Proxmox の Linux ブリッジと Calico IPIP の非互換は既知の問題。
`ipipMode: CrossSubnet` を必ず設定すること。
Proxmox ブリッジ側でフィルタリングを緩める方法もあるが、
ハイパーバイザーの設定を k8s のために変更することになるため推奨しない。

---

## 参考

- [Calico IPPool 設定リファレンス](https://docs.tigera.io/calico/latest/reference/resources/ippool)
- `ansible/roles/k8s_control_plane/tasks/main.yml`
- `docs/architecture/network.puml`
