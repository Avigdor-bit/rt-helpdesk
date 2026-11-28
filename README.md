 🎫 RT Helpdesk — DevOps Final Project

> A Flask + PostgreSQL helpdesk application delivered through a complete DevOps lifecycle: AWS infrastructure as code, container packaging, a kind Kubernetes cluster, Jenkins CI/CD to Amazon ECR, Prometheus/Grafana monitoring, persistent storage, and S3-backed backup and recovery.

---

 📖 Overview

This repository contains the implementation of the RT Helpdesk DevOps final project. It is built around a Flask ticketing application backed by PostgreSQL and deployed to a single-node [kind](https://kind.sigs.k8s.io/) Kubernetes cluster on an AWS EC2 application host. A separate AWS EC2 CI host runs Jenkins (controller + agent), which tests the application, builds and publishes container images to Amazon ECR, and deploys releases to the cluster over SSH.

The project follows the six-milestone course architecture and is backed by execution evidence rather than descriptions of intended functionality.

| Milestone | Status | Summary |
|---|---|---|
| 🟢 M1 — Application and source control | ✅ Complete | Flask/PostgreSQL app, API + health/version endpoints, DB init, tests, Git |
| 🟡 M2 — AWS infrastructure and Terraform | ⚠️ Implemented, with caveat | Two EC2 hosts, VPC/networking, IAM, S3-backed remote state; adoption reconciliation remains |
| 🟢 M3 — Containerization and Kubernetes | ✅ Implemented | kind cluster, app + PostgreSQL deployments, PVC, init job, service, hardening |
| 🟢 M4 — Jenkins CI/CD and Amazon ECR | ✅ Implemented | Checkout, tests, build, ECR push, manual approval, SSH deploy, rollout, smoke test |
| 🟢 M5 — Monitoring, backup and recovery | ✅ Implemented | Prometheus, Grafana, dashboard, DB alert, S3 backup, separate-DB restore verification |
| 🟢 M6 — Documentation and final submission | ✅ Complete | README, API docs, validation docs, evidence package, synchronized GitHub submission |

---

 🏗️ Architecture

```text
AWS region: il-central-1

┌──────────────────────────────────────────────────────────────────────┐
│ AWS VPC / Networking / Security Groups / IAM Instance Profiles       │
│                                                                      │
│  ┌──────────────────────────────┐      ┌───────────────────────────┐ │
│  │ CI host — t3.medium          │      │ App host — t3.large       │ │
│  │                              │      │                           │ │
│  │ Jenkins controller + agent   │      │ Single-node kind cluster  │ │
│  │  - checkout                  │      │                           │ │
│  │  - tests                     │      │ helpdesk namespace        │ │
│  │  - image build               │      │  - Flask application      │ │
│  │  - ECR publication           │      │  - PostgreSQL             │ │
│  │  - release approval          │      │  - PersistentVolumeClaim  │ │
│  │  - SSH deployment            │      │  - init DB job            │ │
│  │  - rollout + smoke test      │      │  - application service    │ │
│  │                              │      │                           │ │
│  │                              │      │ monitoring namespace      │ │
│  │                              │      │  - Prometheus             │ │
│  │                              │      │  - Grafana                │ │
│  └──────────────┬───────────────┘      └─────────────┬─────────────┘ │
│                 │                                    │               │
│                 │ image push/pull                    │ backup/restore│
│                 ▼                                    ▼               │
│        ┌─────────────────┐                  ┌─────────────────────┐  │
│        │ Amazon ECR      │                  │ Amazon S3           │  │
│        │ container images│                  │ Terraform state     │  │
│        └─────────────────┘                  │ PostgreSQL backups  │  │
│                                             └─────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

 Components

| Component | Host / Namespace | Details |
|---|---|---|
| Jenkins controller + agent | CI host (`t3.medium`) | Runs the release pipeline |
| kind cluster | App host (`t3.large`) | Single-node Kubernetes |
| Flask application | `helpdesk` namespace | Non-root UID/GID `10001`, read-only root FS, Gunicorn |
| PostgreSQL | `helpdesk` namespace | PersistentVolumeClaim-backed |
| init DB job | `helpdesk` namespace | Schema initialization (`init-db.yaml`) |
| Prometheus / Grafana | `monitoring` namespace | 15s scrape interval; Grafana 11.4.0 |
| Amazon ECR | AWS | Container image registry |
| Amazon S3 | AWS | Terraform remote state + PostgreSQL backups |

---

 ✅ Prerequisites

Before reproducing the project you will need:

- An AWS account with permissions for EC2, VPC, IAM, ECR, and S3.
- AWS CLI configured for region `il-central-1`.
- Terraform `>= 1.x` installed.
- Docker installed locally (for building and kind).
- `kubectl` and `kind` installed.
- An SSH key pair for accessing the EC2 hosts.
- A GitHub account for source control and the repository.

---

 📂 Repository Structure

```text
rt-helpdesk/
├── README.md
├── app/                        Flask application source
├── tests/                      28 unit/API tests + 8 PostgreSQL integration tests
├── Dockerfile                  Hardened application image
├── compose.yaml                Local development stack
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml         Flask application
│   ├── postgres-deployment.yaml
│   ├── pvc.yaml
│   ├── init-db.yaml            DB initialization job
│   └── service.yaml
├── monitoring/
│   ├── prometheus/
│   └── grafana/
├── terraform/                  VPC, EC2, IAM, S3 backend (26 tracked resources)
├── jenkins/
│   ├── Jenkinsfile
│   └── release.sh
├── docs/
│   ├── API.md
│   ├── CONTAINER_PACKAGING.md
│   ├── Final_Project_Brief.docx
│   ├── SOURCES.md
│   └── VALIDATION.md
├── evidence/
│   ├── ci/README.md
│   ├── image-uid.txt
│   └── local/
│       ├── kubernetes-troubleshooting.txt
│       ├── linux-resource-diagnosis.txt
│       └── s3-restore-verification.txt
├── reference/README.md
└── traffic.py                  Smoke-test traffic generator
```

---

 🛠️ Step-by-Step Build Guide

The steps below mirror the six milestones. Commands are representative of the implementation and should be adapted to your environment.

 Step 1 — Build the Application (Milestone 1)

1. Create the Flask application with ticket-management endpoints, health, and version endpoints.
2. Integrate PostgreSQL using environment-variable configuration.
3. Add a database initialization path so the schema can be created on first boot.
4. Write tests covering the application, API, and PostgreSQL integration.
5. Initialize Git and push the project to GitHub.

```bash
Run the test suite
pytest -v

Expected: 36 passed
  28 application / unit / API tests
   8 PostgreSQL integration tests
```

A successful App CI run is documented here:
🔗 https://github.com/Avigdor-bit/rt-helpdesk/actions/runs/44917156684

---

 Step 2 — Provision AWS Infrastructure (Milestone 2)

1. Configure the Terraform S3 backend with encryption and state locking.
2. Define the VPC and networking (subnets, route tables, internet gateway).
3. Create security groups for the CI host and application host.
4. Create IAM roles and instance profiles for each host.
5. Provision the two EC2 hosts:

| Host | Instance type | Role |
|---|---|---|
| CI host | `t3.medium` | Jenkins controller and agent |
| Application host | `t3.large` | Kubernetes application environment |

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

```hcl
backend.tf (representative)
terraform {
  backend "s3" {
    bucket         = "rt-helpdesk-tfstate"
    key            = "rt-helpdesk/terraform.tfstate"
    region         = "il-central-1"
    encrypt        = true
    dynamodb_table = "rt-helpdesk-tf-lock"
  }
}
```

> ⚠️ Caveat: The existing state tracks 26 resources including both EC2 instances. Additional Terraform adoption-related changes exist in the local working tree but were deliberately excluded from the final submission commit. The committed configuration alone does not establish that every current AWS resource can be recreated without further reconciliation.

---

 Step 3 — Containerize and Deploy to Kubernetes (Milestone 3)

1. Write the Dockerfile with hardening controls:

```dockerfile
Representative hardening
FROM python:3.12-slim
RUN groupadd -g 10001 app && useradd -u 10001 -g app app
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
USER 10001:10001
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

2. Build the image:

```bash
docker build -t rt-helpdesk:local .
```

3. Create the kind cluster on the application host:

```bash
kind create cluster --name rt-helpdesk
kubectl get nodes
```

4. Apply the Kubernetes manifests:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/init-db.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

5. Verify persistence: Replace the PostgreSQL pod and confirm the bound PVC and database fingerprint remain unchanged.

```bash
kubectl -n helpdesk delete pod -l app=postgres
kubectl -n helpdesk get pvc
```

Container hardening applied:

- 🔒 Non-root execution
- 🆔 UID/GID `10001`
- 📖 Read-only root filesystem
- ✍️ Writable `/tmp`
- 🦄 Gunicorn-based serving

---

 Step 4 — Build the Jenkins CI/CD Pipeline (Milestone 4)

1. Install Jenkins on the CI host with a controller/agent arrangement.
2. Create credentials:
   - ECR publisher credential
   - SSH deployment credential
   - Known-hosts file (strict host-key checking)
3. Add a `Jenkinsfile` implementing the eight-step release workflow:

```groovy
pipeline {
  agent any
  stages {
    stage('Checkout')            { steps { checkout scm } }
    stage('Test')                { steps { sh 'pytest -v' } }
    stage('Build Image')         { steps { sh 'docker build -t rt-helpdesk:$BUILD_NUMBER .' } }
    stage('Push to ECR')         { steps { sh './jenkins/ecr-push.sh $BUILD_NUMBER' } }
    stage('Release Approval')    { steps { input 'Approve deployment?' } }
    stage('Deploy')              { steps { sh './jenkins/release.sh $BUILD_NUMBER' } }
    stage('Rollout')             { steps { sh 'kubectl -n helpdesk rollout status deploy/rt-helpdesk' } }
    stage('Smoke Test')          { steps { sh 'python traffic.py' } }
  }
}
```

4. Deploy over SSH to the private application-host address using the release script, then run the smoke test against the cluster service.

> ↩️ Rollback note: A separate rollback demonstration was performed on a disposable local kind cluster by injecting an invalid image digest and restoring a known-good deployment through the release script. This is useful rollback evidence but is not a Jenkins-triggered or AWS-host rollback.

---

 Step 5 — Add Monitoring, Backup and Recovery (Milestone 5)

1. Deploy Prometheus and Grafana into the `monitoring` namespace:

```bash
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
```

2. Configure scraping at a 15-second interval and build the RT Helpdesk dashboard (7 panels).

3. Add a database availability alert and validate it:

```text
Make PostgreSQL unavailable → alert fires after ~60s → restore DB → alert clears
```

> 📣 No external notification delivery (e.g., email/Slack/PagerDuty) is claimed.

4. Implement the backup process:

```bash
Backup (representative)
SA_TOKEN=$(kubectl -n helpdesk create token backup-sa --duration=15m)
PGPASSWORD="$PGPASSWORD" pg_dump -h "$PGHOST" -U "$PGUSER" \
  -Fc "$PGDATABASE" > "backup-$(date +%F).dump"
aws s3 cp "backup-$(date +%F).dump" s3://rt-helpdesk-backups/ --sse
```

5. Verify restore into a separate disposable database:

```bash
Restore into a NEW database (never overwrite the live DB)
createdb rt_helpdesk_restore
pg_restore -d rt_helpdesk_restore backup-YYYY-MM-DD.dump
psql -d rt_helpdesk_restore -c "SELECT count(*) FROM tickets;"
```

Five records were compared and matched against the source, and the live database was not overwritten.

---

 Step 6 — Document, Validate and Submit (Milestone 6)

1. Write the documentation package:

| File | Purpose |
|---|---|
| `README.md` | Project overview and build guide |
| `docs/API.md` | API reference |
| `docs/CONTAINER_PACKAGING.md` | Packaging reference |
| `docs/Final_Project_Brief.docx` | Project brief |
| `docs/SOURCES.md` | Sources |
| `docs/VALIDATION.md` | Validation record |
| `reference/README.md` | Reference implementation notes |

2. Correct the init manifest filename from `init-db.yam` → `init-db.yaml` (contents preserved).

3. Commit and push, then verify synchronization:

```bash
git push origin main
git fetch origin
git rev-list --left-right --count origin/main...HEAD   → 0 0
git rev-parse origin/main                              → a9649c5
git rev-parse HEAD                                     → a9649c5
```

---

 🔐 Security and Operational Practices

| Area | Practice |
|---|---|
| 🆔 Application identity | Non-root UID/GID `10001` |
| 📖 Container filesystem | Read-only root filesystem configuration |
| ✍️ Temporary storage | Writable `/tmp` |
| ✋ CI/CD approval | Manual release approval |
| 🔒 SSH deployment | Strict host-key checking |
| 🪪 AWS access | IAM roles and instance profiles |
| 🗄️ Infrastructure state | Encrypted S3-backed Terraform state |
| 💾 Database storage | Persistent volume claim |
| 📦 Backup | PostgreSQL custom-format dump |
| ♻️ Recovery | Separate-database restore verification |

> ⚠️ These are meaningful DevOps controls but are not a complete commercial production security architecture.

---

 📈 Evidence and Verification

| Evidence | Location |
|---|---|
| 🧪 36 passing tests | Test run / `evidence/ci/` |
| 🔄 App CI run | GitHub Actions run `44917156684` |
| 🚀 Jenkins release + deployment | Jenkins build logs |
| 📤 ECR image publication | ECR console / `evidence/image-uid.txt` |
| 💾 PVC persistence after pod replacement | `evidence/` |
| 🚨 Database alert fire + clear | Grafana / Prometheus |
| ♻️ S3 restore into separate DB | `evidence/local/s3-restore-verification.txt` |
| ↩️ Local rollback demonstration | Local kind evidence |
| 🛠️ Kubernetes troubleshooting | `evidence/local/kubernetes-troubleshooting.txt` |
| 🐧 Linux resource diagnosis | `evidence/local/linux-resource-diagnosis.txt` |

---

 🚧 Known Limitations

The following are not established as completed capabilities by the submitted evidence:

1. ↩️ Jenkins-triggered or AWS-environment rollback
2. 📣 External alert notification delivery
3. 🧱 High availability across multiple replicas or nodes
4. 🌍 Multi-region disaster recovery
5. 🧩 A fully reconciled and revalidated Terraform adoption configuration
6. 📦 Complete acceptance evidence for every Docker and Compose packaging test
7. 🔐 A complete external HTTPS and DNS production-access arrangement
8. 📜 A formal production SLO or commercial support arrangement

> ℹ️ These limitations do not invalidate the demonstrated course workflows — they define the boundary of what has actually been proven.

---

 ✅ Final Submission

The final submission was committed and pushed successfully and is synchronized with GitHub.

| Check | Result |
|---|---|
| `git push origin main` | ✅ Succeeded |
| `git fetch origin` | ✅ Completed |
| `git rev-list --left-right --count origin/main...HEAD` | ✅ `0 0` |
| Remote `origin/main` | ✅ `a9649c5` |
| Local `main` | ✅ `a9649c5` |

🔗 Repository: https://github.com/Avigdor-bit/rt-helpdesk

 Deliberately excluded local changes

The following were preserved locally but not staged, committed, pushed, or applied to AWS during finalization:

- `compose.yaml` modification
- Uncommitted Terraform edits
- Terraform adoption/import proposal files
- Temporary scripts and packages
- Additional untracked evidence and working files

---

 🏆 Overall Assessment

> 🎉 The RT Helpdesk DevOps project has reached a strong course-submission state. It demonstrates the principal DevOps lifecycle — application development, AWS infrastructure, containerization, automated testing, CI/CD, Kubernetes, monitoring, persistence, backup, and recovery — with evidence-backed claims and explicitly documented limitations.

It is not represented as a fully production-hardened commercial platform.

---

 📌 Recommended Next Step

> Preserve commit `a9649c5` as the final submission baseline.

Do not make last-minute infrastructure changes, Terraform imports, AWS modifications, or unrelated file cleanups unless a specific assessment requirement calls for them.

---

# Terraform State Synchronization Verification:

Evidence file — evidence/terraform/state-sync-verification.md

Baseline commit: a9649c5
Region: il-central-1

## Verified
`terraform plan` against the live AWS account reported no unexpected drift.
The 26 tracked resources (both EC2 hosts, VPC, subnets, route tables, IGW,
security groups, IAM roles/instance profiles, S3 backend) are synchronized
with the state.

## What this proves
- Terraform is not merely present in the repository; it manages the current
  AWS infrastructure.
- The committed configuration describes the deployed resources.

## What this does NOT prove
- A complete destroy-and-recreate lifecycle.
- Operational health of Jenkins, Kubernetes, the Flask app, PostgreSQL, or
  Prometheus/Grafana (validated separately).
- That every AWS resource is under Terraform control — only the 26 tracked
  resources are in scope.


---


Final reference: a9649c5 on GitHub main

