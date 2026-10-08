# Ollama in Docker, CPU-only (the Intel HD Graphics 5500 iGPU isn't supported
# by Ollama, so no GPU passthrough).

# Resolving the digest makes `tofu apply` pull a new image when the tag moves.
data "docker_registry_image" "ollama" {
  name = "ollama/ollama:${var.ollama_tag}"
}

resource "docker_image" "ollama" {
  name          = data.docker_registry_image.ollama.name
  pull_triggers = [data.docker_registry_image.ollama.sha256_digest]
  keep_locally  = true
}

resource "docker_container" "ollama" {
  name    = "ollama"
  image   = docker_image.ollama.image_id
  restart = "unless-stopped"
  memory  = var.memory_limit_mb

  env = [
    "OLLAMA_HOST=0.0.0.0:11434",
    "OLLAMA_KEEP_ALIVE=${var.keep_alive}",
    # Old CPU + limited RAM: one model, one request at a time.
    "OLLAMA_MAX_LOADED_MODELS=1",
    "OLLAMA_NUM_PARALLEL=1",
  ]

  ports {
    internal = 11434
    external = var.port
    ip       = var.bind_address
  }

  volumes {
    host_path      = var.data_dir
    container_path = "/root/.ollama"
  }

  healthcheck {
    test         = ["CMD", "ollama", "list"]
    interval     = "30s"
    timeout      = "10s"
    start_period = "10s"
    retries      = 3
  }

  # Block until healthy so the model pulls below don't race the startup.
  wait         = true
  wait_timeout = 120
}

# One resource per model: adding a name pulls it, removing a name deletes it.
resource "terraform_data" "model" {
  for_each = toset(var.models)

  # Destroy-time provisioners may only read `self`, so connection data lives in input.
  input = {
    model     = each.value
    container = docker_container.ollama.name
    host      = var.host
    port      = var.ssh_port
    user      = var.ssh_user
    key       = pathexpand(var.ssh_private_key)
  }

  connection {
    type        = "ssh"
    host        = self.input.host
    port        = self.input.port
    user        = self.input.user
    private_key = file(self.input.key)
  }

  provisioner "remote-exec" {
    inline = ["docker exec ${self.input.container} ollama pull ${self.input.model}"]
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline     = ["docker exec ${self.input.container} ollama rm ${self.input.model} || true"]
  }
}
