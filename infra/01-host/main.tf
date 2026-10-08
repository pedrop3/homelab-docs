# Prepares a plain Ubuntu/Debian server: installs Docker Engine from Docker's
# official apt repo, enables it, and lets the SSH user talk to it.
# Re-runs automatically when the script changes.

locals {
  script = file("${path.module}/scripts/install-docker.sh")
}

resource "terraform_data" "docker" {
  triggers_replace = [sha256(local.script), var.data_root]

  connection {
    type        = "ssh"
    host        = var.host
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key))
  }

  provisioner "file" {
    content     = local.script
    destination = "/tmp/install-docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-docker.sh",
      "DATA_ROOT='${var.data_root}' /tmp/install-docker.sh",
      "rm -f /tmp/install-docker.sh",
    ]
  }
}
