#!/bin/bash
# Update and install python for Ansible
apt-get update
apt-get install -y python3 ufw

# --- NEW: Configure SSH to listen on Port 2222 ---
# 1. Change sshd_config to use Port 2222
sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config
sed -i 's/Port 22/Port 2222/g' /etc/ssh/sshd_config
systemctl restart ssh

# 2. Update Firewall to allow port 2222 instead of OpenSSH (22)
ufw allow 2222/tcp
ufw enable

# --- NEW: Bootstrap Cloudflare Tunnel ---
# 3. Install Cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

# 4. Start the tunnel using the token injected by Terraform
# Terraform will replace ${tunnel_token} with the actual secret
cloudflared service install ${tunnel_token}
systemctl start cloudflared
