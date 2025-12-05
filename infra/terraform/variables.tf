variable "do_token" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "admin_email" {
  type = string
}

variable "domain" {
  type = string
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "size" {
  type    = string
  default = "s-2vcpu-2gb"
}

variable "ssh_pub_path" {
  type    = string
  default = "~/.ssh/id_ed25519_do.pub"
}
