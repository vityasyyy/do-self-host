resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# NEW NAME: cloudflare_zero_trust_tunnel_cloudflared
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "dokploy-tunnel"
  secret     = base64sha256(random_id.tunnel_secret.hex)
}

# prepare zero trust tunnnel
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    ingress_rule {
      hostname = "dokploy.${var.domain}"
      service  = "http://127.0.0.1:3000"
    }
    ingress_rule {
      hostname = "*.${var.domain}"
      service  = "http://127.0.0.1:80"
    }
    ingress_rule {
      hostname = var.domain
      service  = "http://127.0.0.1:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_zero_trust_access_application" "dokploy" {
  zone_id          = var.cloudflare_zone_id
  name             = "Dokploy Admin"
  domain           = "dokploy.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted" # Required in new version
}

resource "cloudflare_zero_trust_access_policy" "admin_only" {
  application_id = cloudflare_zero_trust_access_application.dokploy.id
  zone_id        = var.cloudflare_zone_id
  name           = "Admins Only"
  decision       = "allow"
  precedence     = 1 # <--- REQUIRED now

  include {
    email = [var.admin_email]
  }
}

resource "local_file" "tunnel_token" {
  content  = "tunnel_token: ${cloudflare_zero_trust_tunnel_cloudflared.main.tunnel_token}"
  filename = "${path.module}/../ansible/host_vars/tunnel_secret.yml"
}

# We need to output the IP for Ansible
resource "local_file" "ansible_inventory" {
  content  = <<EOT
[dokploy_servers]
${digitalocean_droplet.server.ipv4_address} ansible_user=root ansible_ssh_private_key_file=${replace(var.ssh_pub_path, ".pub", "")}
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}
