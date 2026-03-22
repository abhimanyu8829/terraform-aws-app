#!/bin/bash
set -uo pipefail
set -x
exec > /var/log/cloud-init-app.log 2>&1

echo "===== cloud-init started at $(date) ====="

# ── 1. System update ─────────────────────────────────────────
apt-get update -y || apt-get update -y
apt-get upgrade -y || true
apt-get install -y curl git ca-certificates gnupg lsb-release unzip || true

# ── AWS CLI install (safe)
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip || true
unzip -q /tmp/awscliv2.zip -d /tmp || true
/tmp/aws/install || true
rm -rf /tmp/aws /tmp/awscliv2.zip || true

# ── 2. Install Docker ─────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings || true

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || true

chmod a+r /etc/apt/keyrings/docker.gpg || true

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y || true

apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin || true

systemctl enable docker || true
systemctl start docker || true

# ── 3. Users ─────────────────────────────────────────────────
usermod -aG docker ubuntu || true

if ! id "${app_docker_user}" &>/dev/null; then
  useradd -m -s /bin/bash "${app_docker_user}" || true
fi

echo "${app_docker_user}:${app_docker_password}" | chpasswd || true
usermod -aG docker "${app_docker_user}" || true

# ── 4. App directory ─────────────────────────────────────────
APP_DIR="/home/${app_docker_user}/app"
mkdir -p "$APP_DIR"

cat > "$APP_DIR/.env" <<EOF
APP_USER=${app_docker_user}
APP_PASSWORD=${app_docker_password}
APP_PORT=${app_port}
EOF

chmod 600 "$APP_DIR/.env"
chown -R "${app_docker_user}:${app_docker_user}" "$APP_DIR"

# ── 5. FIX DOCKER CONFIG (IMPORTANT) ─────────────────────────
rm -rf /root/.docker || true
rm -rf /home/ubuntu/.docker || true
rm -rf /home/${app_docker_user}/.docker || true

# ── 6. Nginx ────────────────────────────────────────────────
apt-get install -y nginx || true
rm -f /etc/nginx/sites-enabled/default || true

cat > /etc/nginx/sites-available/app <<NGINXCONF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
NGINXCONF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app || true
nginx -t || true
systemctl enable nginx || true
systemctl restart nginx || true

# ── 7. Logs ─────────────────────────────────────────────────
touch /var/log/deploy.log
chmod 666 /var/log/deploy.log

# ── 8. Deploy script ─────────────────────────────────────────
echo "Creating deploy.sh..."

cat > /usr/local/bin/deploy.sh <<'DEPLOY'
#!/bin/bash
set -euo pipefail
exec >> /var/log/deploy.log 2>&1

echo "===== Deploy started at $(date) service=$SERVICE tag=$TAG ====="

docker info || { echo "Docker not ready"; exit 1; }

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_ENDPOINT"

echo "ECR login done"

docker pull "$IMAGE:$TAG"

docker stop "$SERVICE" 2>/dev/null || true
docker rm "$SERVICE" 2>/dev/null || true

docker run -d \
  --name "$SERVICE" \
  --restart unless-stopped \
  -p "$APP_PORT:$APP_PORT" \
  "$IMAGE:$TAG"

docker image prune -f

echo "===== Deploy done at $(date) ====="
DEPLOY

chmod +x /usr/local/bin/deploy.sh

echo "deploy.sh created successfully"

# ── 9. Docker socket fix ─────────────────────────────────────
chmod 666 /var/run/docker.sock || true

cat > /etc/systemd/system/docker-socket-fix.service <<'SERVICE'
[Unit]
Description=Fix docker socket permissions
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 666 /var/run/docker.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload || true
systemctl enable docker-socket-fix || true

echo "===== cloud-init finished at $(date) ====="