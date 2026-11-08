 # Homelab docs

Infrastructure code and guides for my homelab: an old laptop running Ubuntu Server that hosts local AI models with [Ollama](https://ollama.com). The whole server is applied from a Mac over SSH, so after a fresh install one command puts it back the way it was.

> [!WARNING]
> Ollama's API has no password. Never forward port `11434` on your router. For access from outside the house, use [Tailscale](infra/README.md#phone-access).

## What's in the repo

| Path | What it is |
| --- | --- |
| [`infra/`](infra/README.md) | Ansible and OpenTofu code, plus the reference for setup, daily commands, configuration and troubleshooting |
| [`guides/`](guides/) | Step-by-step walkthroughs |

## How it works

```text
Mac ── SSH ──> Ubuntu Server
  │              ├─ Ansible:  updates, SSH with keys only, firewall, Docker, Tailscale
  │              └─ OpenTofu: Ollama in Docker, CPU-only, plus the models you list
  │
  └─ make all
```

Ansible owns what's inside Linux, and OpenTofu owns the services on top of it. The firewall only lets the devices you list reach the server, plus your Tailscale network.

## The server

| Part | Spec |
| --- | --- |
| Machine | Old laptop with an SSD, kept running with the lid closed |
| Memory | 11 GB of RAM |
| GPU | Intel HD Graphics 5500, not supported by Ollama, so inference runs on the CPU |

With this hardware, models of 1–4B parameters are the practical range. See [Models on this hardware](infra/README.md#models-on-this-hardware).

## Quick start

You need a Mac with [Homebrew](https://brew.sh) and a server with Ubuntu Server and OpenSSH installed.

```bash
brew install opentofu ansible
cd infra
cp homelab.tfvars.example homelab.tfvars        # server IP and user
cp ansible/local.yml.example ansible/local.yml  # devices allowed to connect
ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<server-ip>
make all
```

The full steps, including creating an SSH key and reserving IPs in the router, are in [`infra/README.md`](infra/README.md#one-time-setup-on-the-mac).

## Guides

- [Flashing disk images to a USB drive with `dd` on macOS](guides/bootable-usb-macos.md): create the Ubuntu installer without installing anything.
- [Running Ollama on the homelab server with OpenTofu](guides/ollama-on-homelab.md): how the Ollama setup works, choosing models and tuning memory.
