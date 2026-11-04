output "api_url" {
  description = "Ollama API endpoint."
  value       = "http://${var.host}:${var.port}"
}

output "models" {
  value = sort(var.models)
}

output "test_command" {
  value = length(var.models) == 0 ? null : "curl http://${var.host}:${var.port}/api/generate -d '{\"model\":\"${var.models[0]}\",\"prompt\":\"Olá!\",\"stream\":false}'"
}
