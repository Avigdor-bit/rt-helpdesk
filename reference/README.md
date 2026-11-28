# Infrastructure reference and setup guide

This folder supplies Terraform, Kubernetes, Linux and Jenkins reference code in addition to the application starter. For the supported 70-90 hour beginner path, provide the setup and permission templates. Students may reuse the examples, but must configure their own repository and environment and explain the result. It is an instructional baseline, not a claim of a verified cloud deployment. Read `../docs/VALIDATION.md` for actual checks.

The reference uses Ubuntu 24.04 amd64, two EC2 instances, one kind cluster, a private Amazon ECR container image, private S3 backups, and SSH tunnels for browser access. Jenkins runs trusted-main builds on a separate Linux user. Prometheus discovers app Pods in the single `helpdesk` namespace. The baseline Grafana dashboard has three panels and the Kubernetes configuration enables one database-unavailable alert. Database and monitoring storage use kind's local storage provider and therefore remain tied to one EC2 host.

The revised baseline uses `helpdesk` and `monitoring`, one API replica, and a direct Jenkins deployment. Older `staging` or `production-demo` resources are not migrated or deleted by these scripts. If you already deployed the earlier version, preserve any needed data and clean up those resources separately after moving to the revised baseline.

Instructor responsibilities: validate the supplied package and installation versions, review the first Terraform plan and provide guidance. Each student uses their own AWS account and available AWS credits, configures account access and budget alerts, sets up the Jenkins controller and agent connection, and creates registry and deployment credentials. The student also configures infrastructure, app manifests, the release job and monitoring, then verifies the required outcomes. No Ansible is needed.

The Docker solution is deliberately excluded from this directory and the student ZIP. Complete `../docs/CONTAINER_PACKAGING.md` before using the build or deployment steps below. The instructor solution is distributed separately.

## 1. AWS and state

Install AWS CLI and Terraform >=1.10, authenticate to your own AWS account using a dedicated lab identity, and generate an SSH key locally. Never commit private keys or AWS access keys. The examples use `eu-west-1`; change it consistently.

Before deployment, confirm your AWS credit balance, expiry, covered services and account restrictions. Set the budget notification to your own email and record your spending limit. The instructor does not provide the AWS account.

From `reference/terraform/bootstrap`:

```sh
terraform init
terraform plan -out=bootstrap.plan -var='region=eu-west-1' -var='state_bucket=YOUR-UNIQUE-STATE-BUCKET'
terraform apply bootstrap.plan
```

Keep the bootstrap directory's local state private and backed up. The state bucket has versioning, encryption, blocked public access and a prevent-destroy rule. The main lab uses that bucket with native S3 lock files. Your Terraform operator needs appropriate state bucket/object permissions including locking and AWS provisioning permissions. The EC2 backup role has no infrastructure-admin permissions.

From `reference/terraform/lab`, copy `backend.hcl.example` to `backend.hcl` and `terraform.tfvars.example` to `terraform.tfvars`. Replace every value marked REPLACE, use your actual public IP `/32`, and paste only the SSH **public** key.

```sh
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -out=lab.plan
terraform apply lab.plan
terraform output
```

Commit the generated provider lock files after review. Ignore plans and local variables. The budget covers the AWS account and sends an actual-spend notification at 80% of your chosen budget. It does not stop resources. The suggested instance sizes are starting points, not a cost quotation. Review instance, disk, IPv4 and storage costs before Apply. The latest matching Ubuntu AMI is selected at plan time; preserve the reviewed plan and record its AMI for reproducibility.

Only port 22 is exposed to the administrator IP. The app also accepts SSH from the CI security group. Use the app's **private IP** in Jenkins. No public application, database, Jenkins, Grafana or Kubernetes API ports are opened.

## 2. Bootstrap Linux

Copy the repository to both hosts, keeping its hidden GitHub files. For the backup systemd unit the app-host path must be `/opt/rt-helpdesk`, readable by `ubuntu`.

On the app host, choose a reviewed kind release and a kubectl version compatible with the kind node image. The script requires explicit versions rather than fetching an unreviewed latest version:

```sh
sudo KIND_VERSION=v0.33.0 KUBECTL_VERSION=YOUR_COMPATIBLE_VERSION bash reference/linux/bootstrap-ubuntu.sh app
```

On the CI host, set an available Jenkins LTS package version from the official Jenkins repository:

```sh
sudo JENKINS_VERSION=YOUR_REVIEWED_LTS_PACKAGE_VERSION bash reference/linux/bootstrap-ubuntu.sh ci
```

Reconnect after installation to refresh Docker group membership. The script installs distro Docker/Compose packages; record their versions. On a teaching image, pin the reviewed package versions. Docker-group users have host-level control. `deploy` must have neither Docker-group membership nor sudo privileges. The shared CI host is a lab compromise; separate controller/agent VMs are a stronger isolation extension.

As `ubuntu` on the app host:

```sh
kind create cluster --name helpdesk --config reference/k8s/kind.yaml
kubectl get nodes
kubectl get storageclass
```

Record the resolved kind node image digest. For a repeated cohort, add `--image kindest/node:VERSION@sha256:DIGEST` with a tested digest from that kind release. Removing the kind cluster loses its local data, even if manifests contain PVCs. Back up before cluster/host replacement.

## 3. First image and application bootstrap

Jenkins builds the runtime image, publishes it to the private AWS ECR repository, and archives its immutable digest as `release-image.txt`. Use the digest from the successful Jenkins build you intend to deploy. Do not build or push a separate GHCR image.

Expected image reference format:

`391924456595.dkr.ecr.il-central-1.amazonaws.com/rt-helpdesk@sha256:YOUR_DIGEST`

Transfer the full reference from `release-image.txt` to the app host. From the repository root on the app host, run:

```sh
bash reference/scripts/bootstrap-app.sh helpdesk 391924456595.dkr.ecr.il-central-1.amazonaws.com/rt-helpdesk@sha256:YOUR_DIGEST
bash reference/scripts/bootstrap-monitoring.sh
```

The app host uses its EC2 instance role for short-lived ECR credentials. Bootstrap creates or refreshes the `ecr-pull` Secret, configures the application ServiceAccount for private image pulls, and enables a systemd timer to refresh credentials every six hours. No static AWS keys or public registry image are required.

Bootstrap creates generated database credentials, one persistent PostgreSQL instance, the non-superuser app role, an initialization Job and one API replica in `helpdesk`. It does not rotate existing database passwords. Initialization can be rerun without deleting tickets. Credential rotation requires a coordinated database change and Secret update.

To open the app, on the application host run:

```sh
kubectl -n helpdesk port-forward service/api 8000:8000
```

On your workstation run `ssh -L 8000:127.0.0.1:8000 ubuntu@APP_PUBLIC_IP`, then open localhost:8000. Use the same two-step method for `service/grafana` in `monitoring` on port 3000, and Prometheus on port 9090. Keep port-forward bound to localhost. Grafana credentials are set interactively during bootstrap. Its Kubernetes dashboard is under DevOps Lab and shows target availability, API request rate and error percentage.

The database container performs its own initial filesystem setup. The API and monitoring run with non-root users and a read-only root filesystem. These manifests intentionally do not enforce a namespace-wide restricted Pod policy on the standard PostgreSQL image.

## 4. Jenkins configuration

Access Jenkins through `ssh -L 8080:127.0.0.1:8080 ubuntu@CI_PUBLIC_IP`. Complete initial setup yourself, create named users and configure authorization. No separate promotion-approval group is required for the baseline. Install Pipeline, Git, Credentials Binding and SSH Build Agents plugins. Disable anonymous access and set the built-in controller executor count to zero.

Configure your own SSH build agent called `helpdesk-build`, label `helpdesk-build`, remote directory `/home/buildagent/agent`, launched as `buildagent` on localhost. Generate a dedicated agent SSH key, place its public key in buildagent's authorized_keys with correct ownership/permissions, and store its private key as a Jenkins credential. Verify the local host key. Do not reuse the cloud administrator key.

Verify the agent is online. Run a small test job restricted to the `helpdesk-build` label that executes `id -un` and `docker version`. Confirm the user is `buildagent`, Docker is reachable, and the controller has zero executors. Preserve this output as setup evidence. One agent process on your own CI host is sufficient; you do not need a third EC2 instance.

Container scanning is an optional extension. The baseline Jenkinsfile does not require Trivy. No credentialed release job may run untrusted PR code.

Provision a dedicated SSH public key for the `deploy` user on the app host. Store its private key in Jenkins using the credential ID **rt-helpdesk-deploy-ssh**, with username `deploy`. Verify the app host's SSH host key through your trusted administrator connection and install the verified entry in `/home/buildagent/.ssh/known_hosts` on the CI host, with ownership and permissions that allow the `buildagent` user to read it. The tracked root `Jenkinsfile` uses this exact path with `StrictHostKeyChecking=yes`; it does not use a Jenkins secret-file credential for known_hosts. Do not rely on an unverified ssh-keyscan result. The entry must match the app host's private address, `10.0.1.138`.

Create namespace-restricted release credentials on the app host:

```sh
bash reference/scripts/issue-release-kubeconfigs.sh
```

Refresh before each lab day. Tokens are requested for 24h and may expire sooner under API-server policy. They are written mode0600 for `deploy`, never printed or committed. The release Role can patch only the API Deployment and inspect/exec Pods within its namespace. This is still a powerful namespace trust boundary. It cannot administer the cluster or modify another namespace's resources through that identity.

Use the Jenkins username/password credential **rt-helpdesk-ecr-publisher** for the scoped ECR publisher identity. Configure the Pipeline-from-SCM job for `*/main` with the repository-root `Jenkinsfile` as its script path. Restrict who can edit this job/repository, and protect main. Do not create a credentialed multibranch job for arbitrary branches.

The tracked repository-root `Jenkinsfile` is the authoritative pipeline configured by the setup instructions. It validates that the checkout is the current trusted `main` revision, reruns the supplied tests against disposable PostgreSQL for that exact SHA, builds the runtime image, publishes it to the private ECR repository, and archives the immutable digest in `release-image.txt`. It then requests manual approval before deployment. After approval, it connects to the application host as `deploy` using strict SSH host-key verification and invokes `reference/scripts/release.sh` for the `helpdesk` namespace. The separate `reference/Jenkinsfile` is an older illustrative template; it is not the active repository-root pipeline.

The release helper performs the digest-pinned deployment, waits for the rollout, checks the application version and readiness, runs a ticket create/read smoke test, and attempts to restore the previous image if the release fails. These deployment and rollback mechanisms are implemented in the pipeline/helper combination. However, implementation is not the same as Jenkins execution evidence: the reviewed Jenkins builds #1–#8 do not establish a Jenkins rollback run. Build #7 is the successful release evidence; the separate local disposable kind-cluster rollback demonstration must not be described as a Jenkins or AWS rollback execution. Preserve this distinction when presenting the project.

GitHub Actions continues to validate PRs with `.github/workflows/ci.yml`. Add Terraform formatting and validation for the configuration you use. Additional manifest and security scans are optional extensions. The Jenkins verification stage reruns tests rather than trusting a branch name or a check from a different SHA.

## 5. Backup, restore and failure exercises

On the app host, AWS CLI obtains the scoped instance role automatically. Test an upload:

```sh
bash reference/scripts/k8s-backup.sh helpdesk YOUR_BACKUP_BUCKET
```

**Optional scheduled backup extension:** create `/etc/helpdesk-backup.env` with `BACKUP_BUCKET=YOUR_BACKUP_BUCKET`, readable by root, then install the units:

```sh
sudo cp reference/linux/helpdesk-backup.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now helpdesk-backup.timer
sudo systemctl start helpdesk-backup.service
sudo journalctl -u helpdesk-backup.service --no-pager
```

The backup runs as the lab administrator `ubuntu`; restrict the repository and systemd unit to trusted maintainers. Giving a separate backup identity database-only access is a useful extension. A backup-role policy prevents S3 deletes, and the bucket expires backups after 14 days.

To test recovery, select one actual object key, download it and restore into a new disposable database. The example deliberately does not overwrite helpdesk:

```sh
umask 077
aws s3 cp s3://YOUR_BACKUP_BUCKET/backups/helpdesk/YOUR_TIMESTAMP.dump restored.dump
kubectl -n helpdesk exec db-0 -- createdb -U postgres helpdesk_restore_check1
kubectl -n helpdesk exec -i db-0 -- pg_restore -U postgres -d helpdesk_restore_check1 --no-owner --no-privileges --exit-on-error < restored.dump
kubectl -n helpdesk exec db-0 -- psql -U postgres -d helpdesk_restore_check1 -c 'SELECT id,title,status FROM helpdesk.tickets ORDER BY id;'
```

Compare with records captured before backup. After inspection, drop only the disposable restore database and remove the local dump. Restore commands fail if that database already exists.

For the required outage exercise, scale the database StatefulSet in `helpdesk` to zero, observe the database-unavailable alert, then scale back to one. Liveness should remain healthy. Existing API Pods stay Running so Prometheus continues scraping them while Service readiness removes them from ordinary traffic. Use port-forward to a Pod to demonstrate API 503s during the outage. Target-down and high-error-rate rules remain optional examples in the Compose configuration. The Kubernetes baseline enables only the database-unavailable rule.

## 6. Teardown

Keep required evidence and test backups first. Delete the kind cluster only after explicitly accepting loss of local volumes. Review `terraform plan -destroy` from the main lab directory. Nonempty backup buckets intentionally block destruction: remove only the lab objects after your retention decision, then destroy the lab. Keep the protected state bucket and bootstrap state until no resources depend on them. Verify remaining EC2, EBS, IPv4, S3 and budget resources in AWS. Stopping an EC2 instance alone is not full teardown.



## Private ECR image pulls and credential refresh

The active RT Helpdesk deployment uses the private Amazon ECR repository
`391924456595.dkr.ecr.il-central-1.amazonaws.com/rt-helpdesk`. The bootstrap
script accepts only this repository and a
SHA-256 digest-pinned image reference.

The application EC2 host must have the `rt-helpdesk-app-host` instance profile
with the narrowly scoped ECR pull policy. Do not place AWS access keys or
ECR passwords in Kubernetes manifests, project files, or systemd units.

Run the application bootstrap from `/opt/rt-helpdesk` on the application host,
using the full ECR image digest. Bootstrap creates the namespace, refreshes
the `ecr-pull` Kubernetes Secret using the EC2 instance role, applies the
ServiceAccount references for the API Deployment and database initialization
Job, and enables the periodic refresh timer.

ECR authorization tokens expire after 12 hours. The systemd timer refreshes
the Kubernetes Secret every six hours. The service runs as `ubuntu`, using
`/home/ubuntu/.kube/config` and the EC2 instance profile.

Check the timer and recent service result on the application host:

```sh
sudo systemctl status helpdesk-ecr-refresh.timer
sudo systemctl list-timers helpdesk-ecr-refresh.timer
sudo journalctl -u helpdesk-ecr-refresh.service --no-pager -n 50
kubectl -n helpdesk get serviceaccount helpdesk-api
kubectl -n helpdesk get secret ecr-pull -o jsonpath='{.type}'; echo
```

Expected Secret type: `kubernetes.io/dockerconfigjson`. Never print or export
the Secret data or ECR authorization token.
