#!/usr/bin/env bash
set -euo pipefail

export AWS_REGION="il-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_SHARED_CREDENTIALS_FILE=/dev/null
export AWS_CONFIG_FILE=/dev/null
export AWS_EC2_METADATA_DISABLED=false
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

NAMESPACE="helpdesk"
SECRET_NAME="ecr-pull"
REGISTRY="391924456595.dkr.ecr.il-central-1.amazonaws.com"

command -v aws >/dev/null
command -v kubectl >/dev/null
command -v python3 >/dev/null

echo "Waiting for Kubernetes API..."
for attempt in $(seq 1 60); do
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo "ERROR: Kubernetes API/namespace unavailable after 5 minutes" >&2
    exit 1
  fi
  sleep 5
done

echo "Refreshing private ECR pull secret..."
aws ecr get-login-password --region "$AWS_REGION" |
python3 -c '
import base64, json, sys
password = sys.stdin.read().strip()
if not password:
    raise SystemExit("ERROR: ECR returned an empty authorization token")
auth = base64.b64encode(("AWS:" + password).encode()).decode()
secret = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "ecr-pull", "namespace": "helpdesk"},
    "type": "kubernetes.io/dockerconfigjson",
    "data": {
        ".dockerconfigjson": base64.b64encode(json.dumps({
            "auths": {
                "391924456595.dkr.ecr.il-central-1.amazonaws.com": {
                    "username": "AWS",
                    "password": password,
                    "auth": auth
                }
            }
        }, separators=(",", ":")).encode()).decode()
    }
}
json.dump(secret, sys.stdout)
' |
kubectl apply --server-side --field-manager=helpdesk-ecr-refresh --force-conflicts -f -

TYPE="$(kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.type}')"
if [ "$TYPE" != "kubernetes.io/dockerconfigjson" ]; then
  echo "ERROR: unexpected Secret type: $TYPE" >&2
  exit 1
fi

echo "ECR pull secret refreshed and verified."
