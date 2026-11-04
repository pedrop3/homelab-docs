# Rebuild the whole homelab:   make all
#
#   make host            -> configure the server with Ansible (Docker, SSH, firewall...)
#   make check-host      -> dry run: show what Ansible would change
#   make ollama          -> deploy Ollama + pull models (OpenTofu)
#   make plan-ollama     -> preview only
#   make destroy-ollama  -> remove Ollama
#   make reinstalled     -> run once after reinstalling the server (then make all)
#
# Connection details are read from homelab.tfvars, shared by Ansible and OpenTofu.

TFVARS := homelab.tfvars
ifeq ($(wildcard $(TFVARS)),)
$(error $(TFVARS) not found. Run: cp homelab.tfvars.example $(TFVARS) and edit it)
endif

# Your own devices allowed through the firewall (git-ignored).
LOCALVARS := ansible/local.yml
ifeq ($(wildcard $(LOCALVARS)),)
$(error $(LOCALVARS) not found. Run: cp ansible/local.yml.example $(LOCALVARS) and edit it)
endif

tfvar     = $(shell sed -nE 's/^$(1)[[:space:]]*=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' $(TFVARS))
HOST     := $(call tfvar,host)
SSH_USER := $(call tfvar,ssh_user)
SSH_KEY  := $(subst ~,$(HOME),$(or $(call tfvar,ssh_private_key),~/.ssh/id_ed25519))
SSH_PORT := $(or $(call tfvar,ssh_port),22)

# --ask-become-pass: Ansible asks for your sudo password once per run.
PLAYBOOK := cd ansible && ansible-playbook site.yml -i '$(HOST),' \
	-e ansible_user=$(SSH_USER) -e ansible_port=$(SSH_PORT) \
	-e ansible_ssh_private_key_file=$(SSH_KEY) -e @local.yml --ask-become-pass

DIR_ollama := tofu/ollama
VARS       := -var-file=$(CURDIR)/$(TFVARS)

.PHONY: all host check-host ollama reinstalled
all: host ollama

host:
	$(PLAYBOOK)

check-host:
	$(PLAYBOOK) --check --diff

ollama:
	tofu -chdir=$(DIR_$@) init -input=false
	tofu -chdir=$(DIR_$@) apply $(VARS)

plan-%:
	tofu -chdir=$(DIR_$*) init -input=false
	tofu -chdir=$(DIR_$*) plan $(VARS)

destroy-%:
	tofu -chdir=$(DIR_$*) destroy $(VARS)

# A reinstalled server has a new SSH key and none of the old containers or
# models. Forget its old key, and set the old OpenTofu state aside so
# everything is created again (kept as *.before-reinstall, not deleted).
reinstalled:
	-ssh-keygen -R $(HOST)
	-ssh-keygen -R '[$(HOST)]:$(SSH_PORT)'
	@for f in $(DIR_ollama)/terraform.tfstate $(DIR_ollama)/terraform.tfstate.backup; do \
		[ -f "$$f" ] && mv "$$f" "$$f.before-reinstall" && echo "moved $$f aside"; \
	done; true