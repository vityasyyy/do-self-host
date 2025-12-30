#!/bin/bash
# Update and install python for Ansible
apt-get update
apt-get install -y python3 ufw

# --- NEW: Configure SSH to listen on Port 2222 ---
# 1. Change sshd_config to use Port 2222
# Remove any existing Port directives (commented or not), then append the desired port
sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' /etc/ssh/sshd_config
echo 'Port 2222' >> /etc/ssh/sshd_config
systemctl restart ssh

# 2. Update Firewall to allow port 2222 instead of OpenSSH (22)
ufw allow 2222/tcp
ufw --force enable

# --- NEW: Bootstrap Cloudflare Tunnel ---
# 3. Install Cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

# 4. Start the tunnel using the token injected by Terraform
# Terraform will replace ${tunnel_token} with the actual secret
if [ -z "${tunnel_token}" ]; then
    echo "Error: tunnel_token is not set or is empty. Cannot install Cloudflared service." >&2
    exit 1
fi

cloudflared service install "${tunnel_token}"
if [ $? -ne 0 ]; then
    echo "Error: 'cloudflared service install' failed. Not starting cloudflared service." >&2
    exit 1
fi
systemctl start cloudflared
