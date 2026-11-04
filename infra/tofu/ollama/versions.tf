terraform {
  required_version = ">= 1.8.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.5"
    }
  }
}

# Talks to the server's Docker daemon over SSH: no Docker port exposed.
provider "docker" {
  host     = "ssh://${var.ssh_user}@${var.host}:${var.ssh_port}"
  ssh_opts = ["-o", "StrictHostKeyChecking=accept-new", "-i", pathexpand(var.ssh_private_key)]
}
