#!/bin/bash
# -----------------------------------------------------------------------
# EC2 bootstrap script (runs once on first boot via Terraform user_data)
# Installs Docker + Nginx and starts the initial application container.
# -----------------------------------------------------------------------
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting EC2 bootstrap $(date) ==="

# --- Install Docker ---
apt-get update -y
apt-get install -y ca-certificates curl gnupg nginx

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# --- Configure Nginx as a reverse proxy to the app container ---
cat > /etc/nginx/sites-available/app.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:${app_port}/health;
    }
}
NGINX_EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
systemctl enable nginx
systemctl restart nginx

# --- Run the initial container (Jenkins Deploy stage updates this later) ---
docker pull ${docker_image} || true
docker run -d \
  --name cicd-demo-app \
  --restart unless-stopped \
  -p ${app_port}:${app_port} \
  ${docker_image} || echo "Initial container run skipped (placeholder image or first boot)"

echo "=== EC2 bootstrap complete $(date) ==="
