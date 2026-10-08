# --- connection (shared via ../homelab.tfvars) ---
variable "host" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_private_key" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

variable "ssh_port" {
  type    = number
  default = 22
}

# --- Ollama ---
variable "ollama_tag" {
  description = "ollama/ollama image tag. Pin a version (e.g. \"0.12.3\") for reproducible deploys."
  type        = string
  default     = "latest"
}

variable "data_dir" {
  description = "Host directory for downloaded models. Survives container rebuilds."
  type        = string
  default     = "/srv/homelab/ollama"
}

variable "bind_address" {
  description = "Host IP the API listens on. 0.0.0.0 = whole LAN; 127.0.0.1 = server only. Ollama has no authentication."
  type        = string
  default     = "0.0.0.0"
}

variable "port" {
  type    = number
  default = 11434
}

variable "keep_alive" {
  description = "How long a model stays in RAM after the last request."
  type        = string
  default     = "10m"
}

variable "memory_limit_mb" {
  description = "Optional RAM cap for the container, in MB. null = no limit."
  type        = number
  default     = null
}

variable "models" {
  description = "Models to pull. CPU-only server: keep to ~1-4B parameters. Removing one from the list deletes it from the server."
  type        = list(string)
  default     = ["llama3.2:3b"]
}
