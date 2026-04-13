resource "digitalocean_ssh_key" "main" {
  name       = "main_ssh_key"
  public_key = file(var.ssh_pub_path)
}
resource "digitalocean_droplet" "server" {
  name      = "dokploy-main"
  image     = "ubuntu-24-04-x64"
  region    = var.region
  size      = var.size
  ssh_keys  = [digitalocean_ssh_key.main.fingerprint]
  user_data = file("${path.module}/../cloud-init.sh")
  backups   = false
  tags      = ["dokploy", "production"]
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "digitalocean_firewall" "strict" {
  name        = "tunnel-only-firewall"
  droplet_ids = [digitalocean_droplet.server.id]

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  dynamic "inbound_rule" {
    for_each = var.maintenance_mode ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "2222"
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }
}
# trigger someting
# trigger something
# trigger domain
# domain change
