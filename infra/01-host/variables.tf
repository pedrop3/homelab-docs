variable "host" {
  description = "IP or hostname of the server."
  type        = string
}

variable "ssh_user" {
  description = "SSH user. Needs passwordless sudo (see README)."
  type        = string
}

variable "ssh_private_key" {
  description = "Path to the SSH private key on this machine."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "data_root" {
  description = "Directory on the server where service data lives (models, volumes)."
  type        = string
  default     = "/srv/homelab"
}
