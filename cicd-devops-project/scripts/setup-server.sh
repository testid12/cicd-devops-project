#!/bin/bash
# -----------------------------------------------------------------------
# setup-server.sh - Manual bootstrap script to install Docker and Nginx
# on a fresh Ubuntu server. This mirrors the logic already embedded in
# terraform/modules/ec2/user_data.sh.tpl and is provided so students can
# also run/understand the setup manually (e.g. for the Jenkins server
# itself, or a spare EC2 box) outside of Terraform.
#
# Usage: sudo ./setup-server.sh
# -----------------------------------------------------------------------
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./setup-server.sh"
  exit 1
fi

echo "==> Updating package index"
apt-get update -y

echo "==> Installing prerequisites"
apt-get install -y ca-certificates curl gnupg nginx git

echo "==> Installing Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "==> Adding current sudo user to docker group"
usermod -aG docker "${SUDO_USER:-$USER}"

systemctl enable docker
systemctl start docker

echo "==> Enabling Nginx"
systemctl enable nginx
systemctl start nginx

echo "==> Verifying installation"
docker --version
nginx -v

echo "==> Setup complete. Log out and back in for docker group membership to take effect."
