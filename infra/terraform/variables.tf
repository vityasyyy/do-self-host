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
  default = "~/.ssh/github_actions_key.pub"
}
variable "maintenance_mode" {
  description = "Enable to open SSH port 2222 and connect via IP for emergency rotation"
  type        = bool
  default     = false
}

variable "rotate_tunnel_token" {
  type    = bool
  default = false
}
