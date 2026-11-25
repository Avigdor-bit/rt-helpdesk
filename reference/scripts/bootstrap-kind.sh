#!/usr/bin/env bash
# Run as ubuntu from the installed project directory on the application host.
set -euo pipefail

repo_dir=${REPO_DIR:-/opt/rt-helpdesk}
cluster_name=${KIND_CLUSTER_NAME:-rt-helpdesk}
config="$repo_dir/reference/k8s/kind.yaml"

[[ $(id -un) == ubuntu ]] || {
  echo "Run this script as ubuntu so the ECR timer uses the same kubeconfig." >&2
  exit 1
}
[[ -f "$config" ]] || {
  echo "Missing kind configuration: $config" >&2
  exit 1
}

export KUBECONFIG="$HOME/.kube/config"
install -d -m 0700 "$HOME/.kube"

if kind get clusters | grep -Fxq "$cluster_name"; then
  echo "kind cluster '$cluster_name' already exists; leaving it unchanged."
else
  kind create cluster \
    --name "$cluster_name" \
    --config "$config" \
    --wait 5m
fi

context="kind-$cluster_name"
kubectl config use-context "$context"
kubectl cluster-info --context "$context"
kubectl get nodes --context "$context" -o wide
