#!/bin/bash
set -euo pipefail

# スクリプトのあるディレクトリに移動
cd "$(dirname "$0")"

# terraformディレクトリでIPとホスト名リストを取得
pushd terraform > /dev/null
ip_list=( $(terraform console <<< 'join("\n", var.workers[*].ip)' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$') )
host_list=( $(terraform console <<< 'join("\n", var.workers[*].name)' | grep -E '^[a-zA-Z0-9._-]+$') )
popd > /dev/null

# openebs-etcdのstsの ETCD_INITIAL_CLUSTER_STATE を"existing"に変更
kubectl patch statefulset openebs-etcd -n openebs -p '{"spec":{"template":{"spec":{"containers":[{"name":"etcd","env":[{"name":"ETCD_INITIAL_CLUSTER_STATE","value":"existing"}]}]}}}}'

# openebs-etcdのstsが3/3 Readyになるまで待機
kubectl rollout status statefulset/openebs-etcd -n openebs --timeout=300s

for i in "${!ip_list[@]}"; do
  ip="${ip_list[$i]}"
  host="${host_list[$i]}"
  echo "[INFO] Rebuilding worker node: $host ($ip)"

  # terraformでrebuild
  pushd terraform > /dev/null
  terraform apply -auto-approve \
    --target="proxmox_virtual_environment_vm.workers[$i]" \
    --replace="proxmox_virtual_environment_vm.workers[$i]"
  popd > /dev/null

  # talhelperで設定流し込み
  pushd talhelper > /dev/null
  talhelper genconfig
  talhelper gencommand apply --extra-flags --insecure -n "$ip" | bash
  popd > /dev/null

  # ノードのReady待ち
  kubectl wait node/"$host" --for=condition=Ready --timeout=300s

  # $host で動いている openebs-etcd- プレフィックスのPod名を取得
  target_etcd_pod=$(kubectl get pods -n openebs -l app=etcd \
    --field-selector=spec.nodeName="$host" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep '^openebs-etcd-' | head -n1)

  # なければskip
  if [[ -z "${target_etcd_pod:-}" ]]; then
    echo "[INFO] No openebs-etcd pod on $host, skip."
    continue
  fi

  # コマンド実行用の etcd Pod を選択（etcd-0 なら 1、それ以外なら 0）
  if [[ "$target_etcd_pod" == "openebs-etcd-0" ]]; then
    runner_etcd_pod="openebs-etcd-1"
  else
    runner_etcd_pod="openebs-etcd-0"
  fi

  # kubectl ~ etcd member list で対象のmember id を取得（$target_etcd_podでgrep）
  member_id=$(kubectl exec -n openebs "$runner_etcd_pod" -c etcd -- etcdctl member list | grep "$target_etcd_pod" | cut -d',' -f1)
  
  # etcdctl member remove <member_id> で削除（runnerで実行）
  kubectl exec -n openebs "$runner_etcd_pod" -c etcd -- etcdctl member remove "$member_id"

  # pvcを削除 (background) — 対象Pod名で特定し、無ければ無視
  kubectl delete pvc -n openebs "data-$target_etcd_pod" --wait=false &

  while [ -z "$(kubectl get pvc -n openebs "data-$target_etcd_pod" -o jsonpath='{.metadata.deletionTimestamp}')" ]; do
    sleep 2
  done

  # podを削除
  kubectl delete pod -n openebs "$target_etcd_pod"

  # PodがRunningになるまで待機
  kubectl rollout status statefulset/openebs-etcd -n openebs --timeout=300s
done

# openebs-etcdのstsの ETCD_INITIAL_CLUSTER_STATE を"new"に戻す
kubectl patch statefulset openebs-etcd -n openebs -p '{"spec":{"template":{"spec":{"containers":[{"name":"etcd","env":[{"name":"ETCD_INITIAL_CLUSTER_STATE","value":"new"}]}]}}}}'

# openebs-etcdのstsが3/3 Readyになるまで待機
kubectl rollout status statefulset/openebs-etcd -n openebs --timeout=300s

echo "[INFO] All worker nodes rebuilt and configured."
