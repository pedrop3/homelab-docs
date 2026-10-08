# Thin wrapper so every stack gets the shared homelab.tfvars.
#   make host            -> prepare the server (Docker)
#   make ollama          -> deploy Ollama + pull models
#   make plan-ollama     -> preview only
#   make destroy-ollama  -> remove
VARS       := -var-file=../homelab.tfvars
DIR_host   := 01-host
DIR_ollama := 02-ollama

.PHONY: all host ollama
all: host ollaollamama

host ollama:
	tofu -chdir=$(DIR_$@) init -input=false
	tofu -chdir=$(DIR_$@) apply $(VARS)

plan-%:
	tofu -chdir=$(DIR_$*) init -input=false
	tofu -chdir=$(DIR_$*) plan $(VARS)

destroy-%:
	tofu -chdir=$(DIR_$*) destroy $(VARS)
