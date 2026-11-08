# Homelab infrastructure

Everything on the server is described in this folder and applied from the Mac over SSH. After a fresh install of the server, `make all` puts it back the way it was.

| Tool | Folder | What it does |
| --- | --- | --- |
| **Ansible** | `ansible/` | Configures the operating system: updates, SSH with keys only, firewall, Docker, laptop tweaks, Tailscale |
| **OpenTofu** | `tofu/ollama/` | Runs Ollama in Docker (CPU-only) and pulls the models you list |

The split follows a simple rule: Ansible owns what's *inside* Linux, OpenTofu owns the services and resources on top of it. Ansible runs first because OpenTofu's Docker provider needs a running Docker daemon.

Related guides: [flashing the Ubuntu installer to a USB drive](../guides/bootable-usb-macos.md) and [a walkthrough of the Ollama setup](../guides/ollama-on-homelab.md).

## Contents

- [One-time setup on the Mac](#one-time-setup-on-the-mac)
- [Rebuild after a reinstall](#rebuild-after-a-reinstall)
- [Day to day](#day-to-day)
- [Configuration](#configuration)
- [What Ansible sets up](#what-ansible-sets-up)
- [Models on this hardware](#models-on-this-hardware)
- [Phone access](#phone-access)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## One-time setup on the Mac

```bash
brew install opentofu ansible
ssh-keygen -t ed25519          # skip if ~/.ssh/id_ed25519 exists; no passphrase
cd infra
cp homelab.tfvars.example homelab.tfvars       # set host / ssh_user
cp ansible/local.yml.example ansible/local.yml # list the devices allowed to connect
ipconfig getifaddr en0                         # your Mac's IP, for local.yml
```

`make` stops with an error until both files exist. Both are git-ignored.

In your router's DHCP settings, reserve the IP of the server and of every device in `local.yml`. If the server's IP changes, `homelab.tfvars` is wrong. If a device's IP changes, the firewall blocks that device.

## Rebuild after a reinstall

For a first install, follow the same steps.

1. **Install Ubuntu Server.** Use the same username, and tick **Install OpenSSH server**.
2. **Copy your key to the server.** This is the last time it asks for the password over SSH.

   ```bash
   cd infra
   make reinstalled          # forgets the old SSH key and the old OpenTofu state
   ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<server-ip>
   ```

3. **Rebuild everything.**

   ```bash
   TS_AUTHKEY=tskey-... make all
   ```

   Create the auth key in the Tailscale admin console. Without `TS_AUTHKEY`, the run still finishes and prints how to log in by hand.

   Ansible asks for your sudo password (`BECOME password`), then OpenTofu shows its plan and waits for `yes`. The models download again, so the first run takes a while.

4. **Test it** from a device in `trusted_lan_hosts`:

   ```bash
   curl http://<server-ip>:11434/api/tags
   ```

The reinstalled server joins Tailscale as a new machine. Remove the old one in the Tailscale admin console.

## Day to day

Run these from `infra/`.

| Task | Command |
| --- | --- |
| Preview what Ansible would change | `make check-host` |
| Apply OS changes | `make host` |
| Change models, update Ollama | edit `homelab.tfvars`, then `make ollama` |
| Preview Ollama changes | `make plan-ollama` |
| Remove Ollama, including its models | `make destroy-ollama` |
| Logs | `ssh <user>@<server-ip> docker logs -f ollama` |

`make host` and `make ollama` are safe to re-run. A second `make host` should finish with `changed=0`.

## Configuration

| File | In git | What goes there |
| --- | --- | --- |
| `homelab.tfvars` | no | Server connection, used by Ansible and OpenTofu, plus optional Ollama settings |
| `ansible/local.yml` | no | `trusted_lan_hosts`: the devices on your home network allowed to connect |
| [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml) | yes | Tailscale on or off, laptop and log settings |

Optional Ollama settings for `homelab.tfvars` (defaults in [`tofu/ollama/variables.tf`](tofu/ollama/variables.tf)):

| Variable | Default | What it does |
| --- | --- | --- |
| `models` | see [below](#models-on-this-hardware) | Models to keep on the server |
| `ollama_tag` | `latest` | Image tag. Pin a version for reproducible rebuilds |
| `keep_alive` | `5m` | How long a model stays in RAM after the last request |
| `context_length` | `2048` | Default context window. Smaller uses less RAM and is faster |
| `memory_limit_mb` | no limit | RAM cap for the container |
| `bind_address` | `0.0.0.0` | Host IP the API listens on. `127.0.0.1` means server only |
| `port` | `11434` | Port the API is published on |
| `data_dir` | `/srv/homelab/ollama` | Where models are stored. Keep it under `data_root` from `all.yml` |

## What Ansible sets up

| Role | Result |
| --- | --- |
| `base` | Automatic security updates, lid closed doesn't suspend, journal capped at 200 MB, zram swap, `/srv/homelab` |
| `ssh` | Login with SSH keys only, no root login. Stops with an error if your key isn't on the server, so it can't lock you out |
| `firewall` | `ufw` blocks incoming traffic except SSH from `trusted_networks` and Tailscale's UDP port 41641. Also filters Docker-published ports (see [Security](#security)) |
| `docker` | Docker Engine from Docker's repo, rotated container logs, your user in the `docker` group |
| `tailscale` | On by default. Private access from your phone and Mac outside the house. Set `tailscale_enabled: false` in `all.yml` to skip it |

## Models on this hardware

The server's GPU is an Intel HD Graphics 5500, which Ollama doesn't support, so inference runs on the CPU (with AVX2).

| Size | Examples | RAM needed | Speed |
| --- | --- | --- | --- |
| 1–2B | `llama3.2:1b`, `qwen2.5:1.5b`, `qwen2.5-coder:1.5b`, `gemma3:1b` | ~2 GB | usable |
| 3–4B | `llama3.2:3b`, `gemma3:4b`, `qwen3:4b` | 3–4 GB | slow but OK |
| 7–8B | `llama3.1:8b`, `qwen2.5:7b` | 6–8 GB | very slow |

The default list is `llama3.2:3b`, `llama3.2:1b` and `qwen2.5-coder:1.5b`. To change it, set `models` in `homelab.tfvars` and run `make ollama`. Adding a name pulls the model, and removing one deletes it from the server.

## Phone access

Any Ollama app on the phone can use `http://<server>:11434`.

- **At home:** use the server's LAN IP. Being on your Wi-Fi isn't enough: add the phone's IP to `trusted_lan_hosts` in `ansible/local.yml`, reserve it in the router, and run `make host`. Turn off private Wi-Fi addressing for this network on the phone, or its IP can change.
- **Away from home:** install Tailscale on the phone and use the server's Tailscale name, `http://homelab:11434`. The server joins your tailnet when you run `TS_AUTHKEY=tskey-... make host`.

Never forward port 11434 on the router: the Ollama API has no password.

## Security

- **Trusted devices.** `trusted_networks` is built from `trusted_lan_hosts` in `ansible/local.yml`, plus the Tailscale range (`100.64.0.0/10`) when Tailscale is on. Every other device on the LAN is dropped. To trust the whole home network, set `trusted_lan_hosts` to `["{{ lan_cidr }}"]`. Which Tailscale devices can connect is decided by the access controls in the Tailscale admin console.
- **Docker skips `ufw`.** Published container ports go through Docker's own firewall rules, so `ufw allow` and `ufw deny` don't affect them. The `firewall` role adds rules to Docker's `DOCKER-USER` chain so only `trusted_networks` can reach any container port.
- **SSH keys.** The SSH key on your Mac is the way in. Back it up somewhere safe, like a password manager. Without it, you need a keyboard and screen on the server.
- **Passwordless sudo is no longer needed.** Ansible asks for the sudo password. If you created `/etc/sudoers.d/90-homelab` for the old setup, you can remove it: `ssh -t <user>@<server-ip> sudo rm /etc/sudoers.d/90-homelab`.
- **State.** OpenTofu keeps its state locally in `tofu/ollama/terraform.tfstate` (git-ignored). After a reinstall it no longer matches the server, which is why `make reinstalled` sets it aside.

## Troubleshooting

| What you see | Fix |
| --- | --- |
| `homelab.tfvars not found` or `ansible/local.yml not found` | Copy the `.example` file (see [One-time setup](#one-time-setup-on-the-mac)) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | The server was reinstalled. `make reinstalled` |
| `Permission denied (publickey)` | `ssh-copy-id -i ~/.ssh/id_ed25519.pub <user>@<server-ip>` |
| `has no ~/.ssh/authorized_keys` | Same as above. Ansible stopped on purpose so you don't get locked out |
| `Missing sudo password` or `Incorrect sudo password` | Type your server user's password at the `BECOME password` prompt |
| SSH times out from the LAN | The Mac's IP probably changed, so the firewall drops it. Get its old IP back from the router, or connect over Tailscale, then update `trusted_lan_hosts` and run `make host` |
| After a reinstall, models are missing or `make ollama` complains about the old container | You skipped `make reinstalled`. Run it, then `make ollama` |
| An app can't reach Ollama | Check that the device's IP is in `trusted_lan_hosts` and that `bind_address` isn't `127.0.0.1`. After changing either one, run `make host` or `make ollama` respectively |
| Tailscale is installed but not logged in | `TS_AUTHKEY=tskey-... make host`, or `ssh -t <user>@<server-ip> sudo tailscale up` |
