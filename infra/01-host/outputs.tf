output "docker_host" {
  description = "Value the next stacks use for the Docker provider."
  value       = "ssh://${var.ssh_user}@${var.host}:${var.ssh_port}"
}

output "data_root" {
  value = var.data_root
}
