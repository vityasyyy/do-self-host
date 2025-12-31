#!/bin/bash
# Update and install python for Ansible
apt-get update
apt-get install -y python3 ufw

# --- NEW: Configure SSH to listen on Port 2222 ---
# 1. Change sshd_config to use Port 2222
# Remove any existing Port directives (commented or not), then append the desired port
sed -i -E '/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+/d' /etc/ssh/sshd_config
echo 'Port 2222' >> /etc/ssh/sshd_config

# Validate SSH configuration before restarting the SSH service to avoid locking out access
if grep -qE '^[[:space:]]*Port[[:space:]]+2222[[:space:]]*$' /etc/ssh/sshd_config && sshd -t -f /etc/ssh/sshd_config; then
  systemctl restart ssh
else
  echo "Error: sshd_config validation failed after setting Port 2222. Not restarting ssh." >&2
  exit 1
fi
# 2. Update Firewall to allow port 2222 instead of OpenSSH (22)
ufw allow 2222/tcp
ufw --force enable

# --- NEW: Bootstrap Cloudflare Tunnel ---
# 3. Install Cloudflared
if ! wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb; then
  echo "Error: Failed to download cloudflared package." >&2
  exit 1
fi
dpkg -i cloudflared-linux-amd64.deb && rm -f cloudflared-linux-amd64.deb

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
