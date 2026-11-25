#!/usr/bin/env bash
set -euo pipefail

ns=${1:?namespace}
bucket=${2:?S3 backup bucket}

[[ "$ns" == helpdesk ]]
[[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]+[a-z0-9]$ ]]

umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Wait up to five minutes for the Kubernetes API to become ready.
ready=false
for attempt in {1..30}; do
  if kubectl get --raw=/readyz --request-timeout=5s >/dev/null 2>&1; then
    ready=true
    break
  fi
  if (( attempt < 30 )); then
    sleep 5
  fi
done
[[ "$ready" == "true" ]] || {
  echo "ERROR: Kubernetes API did not become ready within five minutes." >&2
  exit 1
}


# Obtain a fresh, short-lived token using the administrator kubeconfig.
token=$(kubectl -n "$ns" create token helpdesk-backup --duration=1h)
[[ -n "$token" ]]

# Reuse the current cluster endpoint and CA certificate.
server=$(kubectl config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.server}')

ca_data=$(kubectl config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

if [[ -n "$ca_data" ]]; then
  printf '%s' "$ca_data" | base64 -d > "$work/ca.crt"
else
  ca_file=$(kubectl config view --raw --minify \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')

  [[ -n "$ca_file" && -r "$ca_file" ]] || {
    echo "ERROR: Kubernetes CA certificate is unavailable." >&2
    exit 1
  }

  cp "$ca_file" "$work/ca.crt"
fi

[[ -n "$server" ]]
test -s "$work/ca.crt"

# Build a temporary kubeconfig containing only the backup identity.
kubeconfig="$work/backup.kubeconfig"
touch "$kubeconfig"
chmod 600 "$kubeconfig"

kubectl --kubeconfig="$kubeconfig" config set-cluster backup \
  --server="$server" \
  --certificate-authority="$work/ca.crt" \
  --embed-certs=true >/dev/null

kubectl --kubeconfig="$kubeconfig" config set-credentials backup \
  --token="$token" >/dev/null

kubectl --kubeconfig="$kubeconfig" config set-context backup \
  --cluster=backup \
  --user=backup \
  --namespace="$ns" >/dev/null

kubectl --kubeconfig="$kubeconfig" config use-context backup >/dev/null
unset token

# Export PostgreSQL in custom format using the restricted identity.
stamp=$(date -u +%Y%m%dT%H%M%SZ)

KUBECONFIG="$kubeconfig" kubectl -n "$ns" exec db-0 -- \
  pg_dump -U postgres -d helpdesk -Fc > "$work/backup.dump"

test -s "$work/backup.dump"

# Upload through the EC2 instance profile.
aws s3 cp "$work/backup.dump" \
  "s3://$bucket/backups/$ns/$stamp.dump" --only-show-errors

echo "Backup uploaded: backups/$ns/$stamp.dump"
