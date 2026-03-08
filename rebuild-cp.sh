#!/bin/bash
set -euo pipefail

# スクリプトのあるディレクトリに移動
cd "$(dirname "$0")"

# terraformディレクトリでIPとホスト名リストを取得
pushd terraform > /dev/null
ip_list=( $(terraform console <<< 'join("\n", var.control_planes[*].ip)' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$') )
host_list=( $(terraform console <<< 'join("\n", var.control_planes[*].name)' | grep -E '^[a-zA-Z0-9._-]+$') )
popd > /dev/null


# 1回だけtalhelper genconfig（talhelperディレクトリで実行）
pushd talhelper > /dev/null
talhelper genconfig
popd > /dev/null

for i in "${!ip_list[@]}"; do
  ip="${ip_list[$i]}"
  host="${host_list[$i]}"
  echo "[INFO] Rebuilding control-plane node: $host ($ip)"


  # terraform applyで該当ノードのみ再作成（terraformディレクトリで実行）
  pushd terraform > /dev/null
  terraform apply -auto-approve \
    --target="proxmox_virtual_environment_vm.control_planes[$i]" \
    --replace="proxmox_virtual_environment_vm.control_planes[$i]"
  popd > /dev/null


  # talhelperで設定流し込み（talhelperディレクトリで実行）
  pushd talhelper > /dev/null
  talhelper gencommand apply --extra-flags --insecure -n "$ip" | bash
  popd > /dev/null

  # ノードのReady待ち
  kubectl wait node/"$host" --for=condition=Ready --timeout=300s
done

echo "[INFO] All control-plane nodes rebuilt and configured."
