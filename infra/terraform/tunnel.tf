resource "random_password" "tunnel_secret" {
  length  = 48
  special = false
  keepers = {
    rotate = var.rotate_tunnel_token
  }
}

# 1. Tunnel Resource
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id    = var.cloudflare_account_id
  name          = "dokploy-tunnel"
  config_src    = "cloudflare"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}


# 3. Tunnel Config
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config = {
    ingress = [
      {
        hostname = "ssh.${var.domain}"
        service  = "ssh://127.0.0.1:2222"
      },
      {
        hostname = "dokploy.${var.domain}"
        service  = "http://127.0.0.1:3000"
      },
      {
        hostname = "traefik.${var.domain}"
        service  = "http://127.0.0.1:8080"
      },
      {
        hostname = "*.${var.domain}"
        service  = "http://127.0.0.1:80"
      },
      {
        hostname = var.domain
        service  = "http://127.0.0.1:80"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# 4. DNS Records (New resource name: cloudflare_dns_record)
resource "cloudflare_dns_record" "ssh" {
  zone_id = var.cloudflare_zone_id
  name    = "ssh"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# 5. Access Group (Fixes "object required" error)
resource "cloudflare_zero_trust_access_group" "admins" {
  account_id = var.cloudflare_account_id
  name       = "My Admins"

  include = [{
    email = { email = var.admin_email }
  }]
}

# 6. Access Policy
resource "cloudflare_zero_trust_access_policy" "admin_policy" {
  account_id = var.cloudflare_account_id
  name       = "Admins Only"
  decision   = "allow"

  include = [{
    group = { id = cloudflare_zero_trust_access_group.admins.id }
  }]
}

resource "cloudflare_zero_trust_access_service_token" "ci_deployer" {
  account_id = var.cloudflare_account_id
  name       = "CI/CD Deployer Token"
  duration   = "forever"
}

resource "cloudflare_zero_trust_access_policy" "allow_service_token" {
  account_id = var.cloudflare_account_id
  name       = "Allow CI/CD Bot"
  decision   = "non_identity" # Important: Service tokens are "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.ci_deployer.id
    }
  }]
}

output "cf_service_token_id" {
  value     = cloudflare_zero_trust_access_service_token.ci_deployer.client_id
  sensitive = true
}

output "cf_service_token_secret" {
  value     = cloudflare_zero_trust_access_service_token.ci_deployer.client_secret
  sensitive = true
}

# 7. Access Applications (Fixes "policies" error)
resource "cloudflare_zero_trust_access_application" "dokploy" {
  account_id       = var.cloudflare_account_id
  name             = "Dokploy Admin"
  domain           = "dokploy.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"

  # Policies must be a list of OBJECTS now
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin_policy.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.allow_service_token.id
      precedence = 2
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id       = var.cloudflare_account_id
  name             = "Grafana"
  domain           = "grafana.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_policy.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "prometheus" {
  account_id       = var.cloudflare_account_id
  name             = "Prometheus"
  domain           = "prometheus.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_policy.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "traefik" {
  account_id       = var.cloudflare_account_id
  name             = "Traefik Dashboard"
  domain           = "traefik.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_policy.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "ssh" {
  account_id       = var.cloudflare_account_id
  name             = "ssh vityasy homelab"
  domain           = "ssh.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admin_policy.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.allow_service_token.id
      precedence = 2
    }
  ]
}

# 8. Output Files (Uses the new Data Source)
# Output the Tunnel ID so Ansible can find it
output "tunnel_id" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.main.id
  sensitive = true
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[dokploy_servers]
%{if var.maintenance_mode}
${digitalocean_droplet.server.ipv4_address} ansible_user=root ansible_port=2222 ansible_ssh_private_key_file=${replace(var.ssh_pub_path, ".pub", "")} cf_tunnel_id=${cloudflare_zero_trust_tunnel_cloudflared.main.id}
%{else}
ssh.${var.domain} ansible_user=root ansible_ssh_private_key_file=${replace(var.ssh_pub_path, ".pub", "")} cf_tunnel_id=${cloudflare_zero_trust_tunnel_cloudflared.main.id}
%{endif}
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}
