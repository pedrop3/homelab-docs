# Running Ollama on the homelab server with OpenTofu

This guide sets up [Ollama](https://ollama.com) on the homelab server so any device on your network can run local AI models. OpenTofu installs everything from your Mac over SSH, so you don't install anything by hand on the server. The code is in [`infra/`](../infra/), and [`infra/README.md`](../infra/README.md) has the command reference.

The server in this guide is an Ubuntu machine with 11 GB of RAM and an Intel HD Graphics 5500. Adjust the numbers if your hardware is different.

> [!WARNING]
> Ollama's API has no password. Anyone on your network can use it. Never forward port `11434` on your router. For access from outside the house, use a VPN such as Tailscale or WireGuard.

## Contents

- [How it works](#how-it-works)
- [Before you start](#before-you-start)
- [Deploy](#deploy)
- [Test it](#test-it)
- [Choose models](#choose-models)
- [Tune memory](#tune-memory)
- [Use it day to day](#use-it-day-to-day)
- [Update or remove](#update-or-remove)
- [Troubleshooting](#troubleshooting)
- [Quick reference](#quick-reference)

## How it works

```text
Mac (OpenTofu) ──SSH──▶ server
                         ├─ Docker
                         │   └─ ollama container ──▶ port 11434 on the LAN
                         └─ /srv/homelab/ollama   (downloaded models)
```

The setup runs in two steps, one per folder in `infra/`:

1. **`01-host`** installs Docker from Docker's official repository.
2. **`02-ollama`** starts the Ollama container and downloads the models you list.

They're separate because the second step talks to Docker directly, so Docker has to be installed first.

### Why Docker?

A container isn't a virtual machine. It's a normal process on the server, kept isolated. Ollama uses the same memory inside a container as it would installed directly. Docker itself (`dockerd` and `containerd`) takes roughly 50–100 MB, which is about 1% of 11 GB. The model is what uses memory: a 3B model needs 2–3 GB while it's loaded.

In return, every future service (a chat web UI, monitoring, and so on) is installed, updated and removed the same way, and updating Ollama is just a change of image version.

### Why CPU only?

Ollama doesn't use the Intel HD Graphics 5500 for acceleration. An integrated GPU of that generation also shares the system RAM and wouldn't be faster than the CPU. Ollama runs on the CPU and uses its AVX2 instructions. Expect a few words per second from small models. That's fine for scripts, summaries and quick questions, but slower than ChatGPT.

## Before you start

You only do these once. Replace `192.168.1.50` with your server's IP (`hostname -I` on the server shows it).

1. **Install OpenTofu on the Mac.**

   ```bash
   brew install opentofu
   tofu version
   ```

2. **Set up SSH key login.** If `~/.ssh/id_ed25519` doesn't exist yet, create it with `ssh-keygen -t ed25519` and press Enter at the passphrase prompt. OpenTofu reads the key file directly, so the key can't have a passphrase.

   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub pedrosantos@192.168.1.50
   ssh pedrosantos@192.168.1.50 'echo ok'
   ```

   The second command must print `ok` without asking for a password.

3. **Allow `sudo` without a password.** OpenTofu can't type passwords.

   ```bash
   ssh -t pedrosantos@192.168.1.50 'echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-homelab && sudo chmod 440 /etc/sudoers.d/90-homelab'
   ```

   This asks for your server password one last time.

   > [!CAUTION]
   > Anyone who has this SSH key now has full control of the server. Keep the key on your Mac only and never commit it.

4. **Fill in the variables.**

   ```bash
   cd infra
   cp homelab.tfvars.example homelab.tfvars
   ```

   Open `homelab.tfvars` and set `host` to the server's IP. Git ignores this file, so your IP doesn't end up on GitHub.

## Deploy

From the `infra` folder:

1. **Prepare the server.**

   ```bash
   make host
   ```

   OpenTofu shows what it will do and waits for you to type `yes`. Installing Docker takes 1–3 minutes.

2. **Start Ollama.**

   ```bash
   make ollama
   ```

   After you type `yes`, it downloads the Ollama image (about 1–2 GB) and then the models. A 3B model is about 2 GB.

When it finishes, OpenTofu prints `api_url`, the address you'll use from other devices.

You can run both commands again whenever you like. If nothing changed, OpenTofu reports `No changes` and does nothing.

## Test it

1. **List the models** from the Mac:

   ```bash
   curl http://192.168.1.50:11434/api/tags
   ```

2. **Ask something.**

   ```bash
   curl http://192.168.1.50:11434/api/generate -d '{"model":"llama3.2:3b","prompt":"Explain what a homelab is in one sentence.","stream":false}'
   ```

   The first answer takes longer because the model has to load into memory. Later answers are faster.

## Choose models

With 11 GB of RAM and this CPU:

| Size | Examples | RAM while loaded | Speed here | Good for |
| --- | --- | --- | --- | --- |
| 1–2B | `qwen2.5:1.5b`, `qwen2.5-coder:1.5b`, `gemma3:1b` | ~1.5–2 GB | Fastest | Quick tasks, code completion |
| 3–4B | `llama3.2:3b` (default), `qwen3:4b`, `gemma3:4b` | ~2.5–4 GB | OK | **Best balance for this machine** |
| 7–8B | `llama3.1:8b`, `qwen2.5:7b` | ~5–6 GB | Very slow (1–3 words/s) | Tasks where you can wait |
| 13B and up | — | 9 GB or more | — | Avoid: the server would start using swap |

To change the models, edit `models` in `homelab.tfvars`:

```hcl
models = ["llama3.2:3b", "qwen2.5-coder:1.5b"]
```

Then run `make ollama`. A model you add is downloaded, and a model you remove from the list is deleted from the server.

Browse more models at [ollama.com/library](https://ollama.com/library). Each model's page lists its sizes.

## Tune memory

Two optional settings in `homelab.tfvars`:

```hcl
memory_limit_mb = 8192   # Ollama can use at most 8 GB, leaving ~3 GB for the system
keep_alive      = "30m"  # how long a model stays loaded after the last request
```

- **`memory_limit_mb`** protects the server. Without it, a model that's too big would push the system into swap, and everything would crawl. With it, Ollama refuses the model right away.
- **`keep_alive`** trades memory for speed. Loading a model from disk takes a few seconds. With RAM to spare, keeping it loaded longer avoids that wait. Use a shorter value (`5m`) if you add other services later and need the memory back.

Ollama is also set to keep only one model in memory and answer one request at a time, which suits this CPU.

## Use it day to day

| Task | Command |
| --- | --- |
| Chat in the terminal | `ssh -t pedrosantos@192.168.1.50 docker exec -it ollama ollama run llama3.2:3b` (type `/bye` to exit) |
| See what's loaded in memory | `ssh pedrosantos@192.168.1.50 docker exec ollama ollama ps` |
| Follow the logs | `ssh pedrosantos@192.168.1.50 docker logs -f ollama` |
| Check memory on the server | `ssh pedrosantos@192.168.1.50 free -h` |

Any app that supports Ollama can use it. Point it at `http://192.168.1.50:11434`. Examples are Open WebUI (a ChatGPT-style web page), Continue in VS Code, and Obsidian plugins.

## Update or remove

| Task | How |
| --- | --- |
| Update Ollama | `make ollama`. With the default `ollama_tag = "latest"`, a newer image is pulled if one exists. To update only when you choose, set a fixed version, such as `ollama_tag = "0.12.3"`. |
| Preview changes | `make plan-ollama` shows what would change without touching anything. |
| Remove Ollama | `make destroy-ollama` |

Removing Ollama doesn't delete the model files. They stay in `/srv/homelab/ollama` on the server. To free the space too, run `ssh pedrosantos@192.168.1.50 sudo rm -rf /srv/homelab/ollama`.

## Troubleshooting

| What you see | Cause | Fix |
| --- | --- | --- |
| `Permission denied (publickey)` | The key isn't on the server | Repeat step 2 of [Before you start](#before-you-start) |
| `needs passwordless sudo` | The sudo step was skipped | Repeat step 3 of [Before you start](#before-you-start) |
| `Host key verification failed` | The server was reinstalled, or the IP now belongs to another machine | `ssh-keygen -R 192.168.1.50`, then `ssh pedrosantos@192.168.1.50` once and answer `yes` |
| `permission denied while trying to connect to the Docker daemon socket` | Your user isn't in the `docker` group yet | Run `make host` again, then retry `make ollama` |
| `curl: (7) Failed to connect` from another device | Firewall, or `bind_address` set to `127.0.0.1` | On the server, `sudo ufw status`. If it's active: `sudo ufw allow from 192.168.1.0/24 to any port 11434` |
| A model download stops halfway | Network dropped | Run `make ollama` again. The download resumes |
| `model requires more system memory` | The model is bigger than `memory_limit_mb` allows | Choose a smaller model from [Choose models](#choose-models) |
| Answers are extremely slow, and `free -h` shows swap in use | The model is too big for the RAM | Use a 3B model, and set `memory_limit_mb` |
| The first answer takes 10+ seconds, later ones are faster | The model is loading from disk | Normal. Raise `keep_alive` to keep it loaded |

## Quick reference

```bash
# One time, on the Mac
brew install opentofu
ssh-copy-id -i ~/.ssh/id_ed25519.pub pedrosantos@192.168.1.50
cd infra && cp homelab.tfvars.example homelab.tfvars   # set host

# Deploy (both are safe to re-run)
make host
make ollama

# Test
curl http://192.168.1.50:11434/api/tags

# Change models: edit `models` in homelab.tfvars, then
make ollama

# Preview / remove
make plan-ollama
make destroy-ollama
```
