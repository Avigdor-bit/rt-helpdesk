#!/usr/bin/env bash
# Ubuntu 24.04 amd64. Run as root: bootstrap-ubuntu.sh app|ci
set -euo pipefail

role=${1:?Usage: bootstrap-ubuntu.sh app|ci}
[[ "$role" == app || "$role" == ci ]]
[[ $(uname -m) == x86_64 ]]
[[ $EUID -eq 0 ]] || { echo "Run this script as root." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates curl gnupg git python3 python3-venv unzip jq \
  openssh-server docker.io docker-compose-v2

systemctl enable --now ssh docker
usermod -aG docker ubuntu

install -d -o root -g root -m 0755 /opt/rt-helpdesk

if [[ "$role" == app ]]; then
  : "${KIND_VERSION:?Set a reviewed kind version}"
  : "${KUBECTL_VERSION:?Set a reviewed kubectl version}"

  # Install AWS CLI v2 using the official AWS installer.
  # Use the supported update command when already installed by that installer.
  if [[ -x /usr/local/bin/aws ]] && \
     /usr/local/bin/aws --version 2>&1 | grep -q '^aws-cli/2\.'; then
    /usr/local/bin/aws update
  else
    curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash -s -- --system
  fi

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT

  curl -fL "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64" \
    -o "$work/kind"
  curl -fL "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64.sha256sum" \
    -o "$work/kind.sha256"
  (cd "$work"; sed 's/kind-linux-amd64/kind/' kind.sha256 | sha256sum -c -)
  install -o root -g root -m 0755 "$work/kind" /usr/local/bin/kind

  curl -fL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" \
    -o "$work/kubectl"
  curl -fL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256" \
    -o "$work/kubectl.sha256"
  (cd "$work"; printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum -c -)
  install -o root -g root -m 0755 "$work/kubectl" /usr/local/bin/kubectl

  id deploy >/dev/null 2>&1 ||
    useradd --create-home --shell /bin/bash deploy

else
  apt-get install -y fontconfig openjdk-21-jre

  install -d -o root -g root -m 0755 /etc/apt/keyrings
  curl -fsSL \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /etc/apt/keyrings/jenkins-keyring.asc
  chmod 0644 /etc/apt/keyrings/jenkins-keyring.asc

  echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' \
    > /etc/apt/sources.list.d/jenkins.list

  apt-get update
  : "${JENKINS_VERSION:?Set an available, reviewed Jenkins LTS package version}"
  apt-get install -y "jenkins=$JENKINS_VERSION"
  apt-mark hold jenkins

  id buildagent >/dev/null 2>&1 ||
    useradd --create-home --shell /bin/bash buildagent
  usermod -aG docker buildagent

  # Enforce the course architecture: controller does not execute builds.
  install -d -o root -g root -m 0755 /var/lib/jenkins/init.groovy.d
  cat > /var/lib/jenkins/init.groovy.d/disable-controller-executors.groovy <<'GROOVY'
import jenkins.model.Jenkins

Jenkins.instance.setNumExecutors(0)
Jenkins.instance.save()
GROOVY
  chown jenkins:jenkins \
    /var/lib/jenkins/init.groovy.d/disable-controller-executors.groovy
  chmod 0644 \
    /var/lib/jenkins/init.groovy.d/disable-controller-executors.groovy

  systemctl enable jenkins
  systemctl restart jenkins
fi

echo "Host bootstrap packages and role configuration installed."
echo "Reconnect SSH before using Docker group permissions."
