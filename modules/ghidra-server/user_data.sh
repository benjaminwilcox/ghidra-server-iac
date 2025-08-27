#!/bin/bash
set -euo pipefail

# variables from tf
GHIDRA_USERS="${ghidra_users}"
PROJECT_NAME="${project_name}"

# logs
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Ghidra server setup..."

# update system
apt-get update -y
apt-get upgrade -y

# install & enable ssm agent
if ! systemctl is-active --quiet amazon-ssm-agent; then
  if command -v snap >/dev/null 2>&1; then
    snap install amazon-ssm-agent --classic || true
    systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
  fi
  if ! systemctl is-active --quiet amazon-ssm-agent; then
    apt-get update -y
    apt-get install -y amazon-ssm-agent || true
    systemctl enable --now amazon-ssm-agent || true
  fi
fi

# install Docker
apt-get install -y --no-install-recommends docker.io git curl wget unzip dnsutils
systemctl enable --now docker
usermod -aG docker ubuntu

# create directories
mkdir -p /home/ubuntu/repos
mkdir -p /home/ubuntu/ghidra-setup
chown -R ubuntu:ubuntu /home/ubuntu

# create ghidra docker setup
cd /home/ubuntu/ghidra-setup

# create dockerfile
cat > Dockerfile << 'EOF'
FROM openjdk:11-jdk-slim

ENV VERSION=10.1.2
ENV FILE_NAME=ghidra_$${VERSION}_PUBLIC_20220125.zip
ENV DL=https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_$${VERSION}_build/$${FILE_NAME}
ENV GHIDRA_SHA256=ac96fbdde7f754e0eb9ed51db020e77208cdb12cf58c08657a2ab87cb2694940

RUN apt-get update && apt-get install -y wget unzip dnsutils --no-install-recommends \
    && wget --progress=bar:force -O /tmp/ghidra.zip $${DL} \
    && echo "$GHIDRA_SHA256 /tmp/ghidra.zip" | sha256sum -c - \
    && unzip /tmp/ghidra.zip \
    && mv ghidra_$${VERSION}_PUBLIC /ghidra \
    && chmod +x /ghidra/ghidraRun \
    && apt-get purge -y --auto-remove wget unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /ghidra/docs /ghidra/Extensions/Eclipse /ghidra/licenses

WORKDIR /ghidra

COPY entrypoint.sh /entrypoint.sh
COPY server.conf /ghidra/server/server.conf

EXPOSE 13100 13101 13102

RUN mkdir /repos

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
EOF

# create entrypoint script
cat > entrypoint.sh << 'EOF'
#!/bin/bash
set -e

if [ "$1" = 'server' ]; then
  shift

  GHIDRA_USERS=$${GHIDRA_USERS:-admin}
  if [ ! -e "/repos/users" ] && [ ! -z "$${GHIDRA_USERS}" ]; then
    mkdir -p /repos/~admin
    for user in $${GHIDRA_USERS}; do
      echo "Adding user: $${user}"
      echo "-add $${user}" >> /repos/~admin/adm.cmd
    done
  fi

  exec "/ghidra/server/ghidraSvr" console
fi

exec "$@"
EOF

chmod +x entrypoint.sh

# create server conf
cat > server.conf << 'EOF'
wrapper.working.dir=$${ghidra_home}
wrapper.java.command=$${java}
wrapper.java.umask=027
include=$${classpath_frag}
wrapper.java.library.path.1=$${os_dir}
wrapper.java.additional.1=-Djava.net.preferIPv4Stack=true
wrapper.java.additional.2=-DApplicationRollingFileAppender.maxBackupIndex=10
wrapper.java.additional.3=-Dclasspath_frag=$${classpath_frag}
wrapper.java.additional.8=-Ddb.buffers.DataBuffer.compressedOutput=true
wrapper.java.monitor.deadlock=true
wrapper.java.app.mainclass=ghidra.server.remote.GhidraServer
wrapper.java.initmemory=396
wrapper.java.maxmemory=768
ghidra.repositories.dir=/repos
wrapper.app.parameter.1=-a0
wrapper.app.parameter.2=-u
wrapper.app.parameter.3=-ip$${GHIDRA_PUBLIC_HOSTNAME}
wrapper.app.parameter.4=$${ghidra.repositories.dir}
wrapper.console.format=PM
wrapper.console.loglevel=INFO
wrapper.logfile=wrapper.log
wrapper.logfile.format=LPTM
wrapper.logfile.loglevel=INFO
wrapper.logfile.maxsize=10m
wrapper.logfile.maxfiles=10
wrapper.console.title=Ghidra Server
EOF

# change ownership
chown -R ubuntu:ubuntu /home/ubuntu/ghidra-setup

# build docker image
echo "Building Ghidra server Docker image..."
docker build . -t "$PROJECT_NAME/ghidra-server:latest"

# get public ip
PUBLIC_IP="$(
  curl -s --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 \
  || echo "127.0.0.1"
)"

# run ghidra server container
echo "Starting Ghidra server container..."
docker run -d \
    --name ghidra-server \
    --restart unless-stopped \
    -e GHIDRA_USERS="$GHIDRA_USERS" \
    -e GHIDRA_PUBLIC_HOSTNAME="$PUBLIC_IP" \
    -v /home/ubuntu/repos:/repos \
    -p 13100-13102:13100-13102 \
    "$PROJECT_NAME/ghidra-server:latest"

# wait and verify
sleep 10

if docker ps | grep -q ghidra-server; then
    echo "Ghidra server started successfully!"
    docker ps --filter name=ghidra-server
else
    echo "Ghidra server failed to start!"
    docker logs ghidra-server
    exit 1
fi

# create management script
cat > /home/ubuntu/check-status.sh << 'EOF'
#!/bin/bash
echo "=== Ghidra Server Status ==="
IP="$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 || echo unknown)"
echo "Server IP: $IP"
echo "Container Status:"
docker ps --filter name=ghidra-server --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Recent Logs (last 10 lines):"
docker logs --tail 10 ghidra-server
EOF

chmod +x /home/ubuntu/check-status.sh
chown ubuntu:ubuntu /home/ubuntu/check-status.sh

# create systemd service for auto-restart
cat > /etc/systemd/system/ghidra-server.service << EOF
[Unit]
Description=Ghidra Server Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/docker start -a ghidra-server
ExecStop=/usr/bin/docker stop ghidra-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ghidra-server.service

echo ""
echo "Ghidra Server Setup Complete!"
/home/ubuntu/check-status.sh || true
echo "Server IP: $PUBLIC_IP"
echo "Ghidra Port: 13100"
echo "Users: $GHIDRA_USERS"
echo "Default Password: changeme"
echo ""
echo "Check status: sudo /home/ubuntu/check-status.sh"
echo "View logs: sudo docker logs ghidra-server"