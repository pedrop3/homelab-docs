# Homelab infrastructure

Everything on the server is described in this folder and applied from the Mac over SSH. After a fresh install of the server, `make all` puts it back the way it was.

| Tool | Folder | What it does |
| --- | --- | --- |
| **Ansible** | `ansible/` | Configures the operating system: updates, SSH with keys only, firewall, Docker, laptop tweaks, optional Tailscale |
| **OpenTofu** | `tofu/ollama/` | Runs Ollama in Docker (CPU-only) and pulls the models you list |

The split follows a simple rule: Ansible owns what's *inside* Linux, OpenTofu owns the services and resources on top of it. Ansible runs first because OpenTofu's Docker provider needs a running Docker daemon.

## What Ansible sets up

| Role | Result |
| --- | --- |
| `base` | Automatic security updates, lid closed doesn't suspend, journal capped at 200 MB, zram swap, `/srv/homelab` |
| `ssh` | Login with SSH keys only, no root login. Stops with an error if your key isn't on the server, so it can't lock you out |
| `firewall` | `ufw` blocks all incoming traffic except SSH from `trusted_networks`. Also filters Docker-published ports (see [Security](#security)) |
| `docker` | Docker Engine from Docker's repo, rotated container logs, your user in the `docker` group |
| `tailscale` | Off by default. Private access from your phone and Mac outside the house |

Settings are in [`ansible/group_vars/all.yml`](ansible/group_vars/all.yml).

## One-time setup on the Mac

```bash
brew install opentofu ansible
ssh-keygen -t ed25519          # skip if ~/.ssh/id_ed25519 exists; no passphrase
cd infra
cp homelab.tfvars.example homelab.tfvars   # set host / ssh_user
```

Reserve the server's IP in your router's DHCP settings, so it doesn't change and break `homelab.tfvars`.

## Rebuild after a reinstall

1. **Install Ubuntu Server.** Use the same username, and tick **Install OpenSSH server**.
2. **Copy your key to the server.** This is the last time it asks for the password over SSH.

   ```bash
   cd infra
   make reinstalled          # forgets the old SSH key and the old OpenTofu state
   ssh-copy-id -i ~/.ssh/id_ed25519.pub pedrosantos@xxx.xxx.x.x
   ```

3. **Rebuild everything.**

   ```bash
   make all
   ```

   Ansible asks for your sudo password (`BECOME password`), then OpenTofu shows its plan and waits for `yes`. The models download again, so the first run takes a while.

4. **Test it** with the Bruno collection, or `curl http://192.168.1.149:11434/api/tags`.

If you use Tailscale, the reinstalled server joins as a new machine. Remove the old one in the Tailscale admin console.

## Day to day

| Task | Command |
| --- | --- |
| Preview what Ansible would change | `make check-host` |
| Apply OS changes | `make host` |
| Change models, update Ollama | edit `homelab.tfvars`, then `make ollama` |
| Preview Ollama changes | `make plan-ollama` |
| Remove Ollama | `make destroy-ollama`. Models stay in `/srv/homelab/ollama` |
| Logs | `ssh pedrosantos@192.168.1.149 docker logs -f ollama` |

Everything is safe to re-run. A second `make host` should finish with `changed=0`.

## Models on this hardware

The server's GPU is an Intel HD Graphics 5500, which Ollama doesn't support, so inference runs on the CPU (with AVX2).

| Size | Examples | RAM needed | Speed |
| --- | --- | --- | --- |
| 1–2B | `qwen2.5:1.5b`, `qwen2.5-coder:1.5b`, `gemma3:1b` | ~2 GB | usable |
| 3–4B | `llama3.2:3b` (default), `gemma3:4b`, `qwen3:4b` | 3–4 GB | slow but OK |
| 7–8B | `llama3.1:8b`, `qwen2.5:7b` | 6–8 GB | very slow |

To change the list, set `models` in `homelab.tfvars` and run `make ollama`. Adding a name pulls the model, and removing one deletes it from the server.

## Phone access

Any Ollama app on the phone can use `http://<server>:11434`.

- **At home:** use the server's LAN IP. The phone is on your Wi-Fi, which is a trusted network.
- **Away from home:** set `tailscale_enabled: true` in `group_vars/all.yml`, create an auth key in the Tailscale admin console, and run `TS_AUTHKEY=tskey-... make host`. Install Tailscale on the phone and use the server's Tailscale name, `http://homelab:11434`.

Never forward port 11434 on the router: the Ollama API has no password.

## Security

- **Docker skips `ufw`.** Published container ports go through Docker's own firewall rules, so `ufw allow` and `ufw deny` don't affect them. The `firewall` role adds rules to Docker's `DOCKER-USER` chain so only `trusted_networks` can reach any container port. To allow fewer devices, list single IPs in `trusted_networks`, such as `192.168.1.20/32`.
- **SSH keys.** The SSH key on your Mac is the way in. Back it up somewhere safe, like a password manager. Without it, you need a keyboard and screen on the server.
- **Passwordless sudo is no longer needed.** Ansible asks for the sudo password. If you created `/etc/sudoers.d/90-homelab` for the old setup, you can remove it: `ssh -t pedrosantos@192.168.1.149 sudo rm /etc/sudoers.d/90-homelab`.
- **State.** OpenTofu keeps its state locally in `tofu/ollama/terraform.tfstate` (git-ignored). After a reinstall it no longer matches the server, which is why `make reinstalled` sets it aside.

## Troubleshooting

| What you see | Fix |
| --- | --- |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | The server was reinstalled. `make reinstalled` |
| `Permission denied (publickey)` | `ssh-copy-id -i ~/.ssh/id_ed25519.pub pedrosantos@<ip>` |
| `has no ~/.ssh/authorized_keys` | Same as above. Ansible stopped on purpose so you don't get locked out |
| `Missing sudo password` or `Incorrect sudo password` | Type your server user's password at the `BECOME password` prompt |
| After a reinstall, models are missing or `make ollama` complains about the old container | You skipped `make reinstalled`. Run it, then `make ollama` |
| An app can't reach Ollama | Check that the device's IP is in `trusted_networks`, then `make host` |
