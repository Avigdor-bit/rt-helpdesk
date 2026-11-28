#!/usr/bin/env bash
# Run from repository root on the application host as the cluster administrator.
set -euo pipefail
ns=${1:?Usage: bootstrap-app.sh helpdesk IMAGE_DIGEST}
image=${2:?Supply the private ECR image reference by digest}
[[ "$ns" == helpdesk ]]
[[ "$image" =~ ^391924456595\.dkr\.ecr\.il-central-1\.amazonaws\.com/rt-helpdesk@sha256:[a-f0-9]{64}$ ]]

expected_context="kind-${KIND_CLUSTER_NAME:-rt-helpdesk}"
actual_context=$(kubectl config current-context)
if [[ "$actual_context" != "$expected_context" ]]; then
  echo "ERROR: Expected kubectl context '$expected_context', found '$actual_context'." >&2
  echo "Run reference/scripts/bootstrap-kind.sh as ubuntu first." >&2
  exit 1
fi

kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
bash reference/scripts/refresh-ecr-secret.sh
# Preserve existing credentials; never rotate passwords on an existing database.
app_secret=$(kubectl -n "$ns" get secret app-secret --ignore-not-found -o name)
db_secret=$(kubectl -n "$ns" get secret db-secret --ignore-not-found -o name)

if [[ -z "$app_secret" && -z "$db_secret" ]]; then
  secret_dir=$(mktemp -d); chmod 700 "$secret_dir"
  trap 'rm -rf "$secret_dir"' EXIT
  python3 - "$secret_dir" <<'PY'
import secrets,sys,pathlib
for name,key in [('app','DB_PASSWORD'),('db','POSTGRES_PASSWORD')]:
 p=pathlib.Path(sys.argv[1])/name
 p.write_text(key+'='+secrets.token_hex(24)+'\n')
 p.chmod(0o600)
PY
  kubectl -n "$ns" create secret generic app-secret --from-env-file="$secret_dir/app"
  kubectl -n "$ns" create secret generic db-secret --from-env-file="$secret_dir/db"
elif [[ -z "$app_secret" || -z "$db_secret" ]]; then
  echo "ERROR: Only one database secret exists. Refusing to generate or rotate credentials." >&2
  exit 1
fi
sed "s|REPLACE_IMAGE|$image|g" reference/k8s/app.yaml | kubectl -n "$ns" apply -f -
kubectl -n "$ns" patch configmap app-config --type merge -p "{\"data\":{\"APP_ENV\":\"$ns\"}}"
kubectl -n "$ns" rollout status statefulset/db --timeout=300s
kubectl -n "$ns" delete job init-db --ignore-not-found --wait=true
sed "s|REPLACE_IMAGE|$image|g" reference/k8s/init-db.yaml | kubectl -n "$ns" apply -f -
kubectl -n "$ns" wait --for=condition=complete job/init-db --timeout=200s
kubectl -n "$ns" rollout restart deployment/api
kubectl -n "$ns" rollout status deployment/api --timeout=180s
kubectl -n "$ns" apply -f reference/k8s/release-rbac.yaml
kubectl -n "$ns" apply -f reference/k8s/backup-rbac.yaml
kubectl -n "$ns" exec deployment/api -- flask --app app seed-db

# Install periodic private ECR pull-secret refresh on the app host.
sudo install -m 0644 reference/linux/helpdesk-ecr-refresh.service /etc/systemd/system/
sudo install -m 0644 reference/linux/helpdesk-ecr-refresh.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now helpdesk-ecr-refresh.timer

# Configure the daily PostgreSQL backup to the existing private S3 bucket.
backup_bucket="rt-helpdesk-backups-391924456595-ilc1"
printf 'BACKUP_BUCKET=%s\n' "$backup_bucket" |
  sudo tee /etc/helpdesk-backup.env >/dev/null
sudo chmod 0600 /etc/helpdesk-backup.env
sudo chown ubuntu:ubuntu /etc/helpdesk-backup.env

sudo install -m 0644 reference/linux/helpdesk-backup.service /etc/systemd/system/
sudo install -m 0644 reference/linux/helpdesk-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now helpdesk-backup.timer
