#!/usr/bin/env bash
# Idempotent: safe to run many times.
set -euo pipefail

if ! sudo -n true 2>/dev/null; then
  echo "ERROR: '$USER' needs passwordless sudo. See infra/README.md." >&2
  exit 1
fi

. /etc/os-release   # gives $ID (ubuntu|debian) and $VERSION_CODENAME
case "$ID" in
  ubuntu|debian) ;;
  *) echo "ERROR: unsupported distro '$ID' (expected ubuntu or debian)" >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo ">> Installing Docker Engine"
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo ">> Docker already installed: $(docker --version)"
fi

sudo systemctl enable --now docker

# Lets OpenTofu's Docker provider connect over SSH without sudo.
# Takes effect on the next SSH login (the next stack opens a new one).
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi

sudo mkdir -p "${DATA_ROOT}"
echo ">> Host ready. Data root: ${DATA_ROOT}"
