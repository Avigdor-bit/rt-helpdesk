#!/usr/bin/env bash
# Run as root on the CI host after creating an inbound agent in Jenkins.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

: "${JENKINS_URL:?Set the reachable Jenkins controller URL}"
: "${AGENT_NAME:?Set the exact Jenkins inbound-agent node name}"
: "${AGENT_SECRET:?Set the node secret from the Jenkins UI}"

[[ "$JENKINS_URL" =~ ^https?://[^[:space:]]+$ ]]
[[ "$AGENT_NAME" =~ ^[A-Za-z0-9._-]+$ ]]
[[ "$AGENT_SECRET" =~ ^[A-Za-z0-9]+$ ]]

id buildagent >/dev/null
install -d -o root -g root -m 0755 /opt/rt-helpdesk/jenkins-agent
install -d -o buildagent -g buildagent -m 0750 /home/buildagent/agent
install -d -o root -g root -m 0750 /etc/rt-helpdesk

curl -fsS "$JENKINS_URL/jnlpJars/agent.jar" \
  -o /opt/rt-helpdesk/jenkins-agent/agent.jar
chown root:root /opt/rt-helpdesk/jenkins-agent/agent.jar
chmod 0644 /opt/rt-helpdesk/jenkins-agent/agent.jar

umask 077
cat > /etc/rt-helpdesk/jenkins-agent.env <<ENV
JENKINS_URL=$JENKINS_URL
AGENT_NAME=$AGENT_NAME
AGENT_SECRET=$AGENT_SECRET
ENV
chmod 0600 /etc/rt-helpdesk/jenkins-agent.env

cat > /etc/systemd/system/rt-helpdesk-jenkins-agent.service <<'UNIT'
[Unit]
Description=RT Helpdesk dedicated Jenkins build agent
Wants=network-online.target
After=network-online.target jenkins.service

[Service]
Type=simple
User=buildagent
Group=buildagent
EnvironmentFile=/etc/rt-helpdesk/jenkins-agent.env
WorkingDirectory=/home/buildagent/agent
ExecStart=/usr/bin/java -jar /opt/rt-helpdesk/jenkins-agent/agent.jar -url ${JENKINS_URL}/ -secret ${AGENT_SECRET} -name ${AGENT_NAME} -webSocket -workDir /home/buildagent/agent
Restart=always
RestartSec=10
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable rt-helpdesk-jenkins-agent.service

echo "Agent service installed but not started."
echo "Verify the Jenkins node name and label before starting it."
