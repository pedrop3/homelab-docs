# Homelab infrastructure (OpenTofu)

Everything on the server is installed by OpenTofu, run from your Mac over SSH. Nothing is installed by hand except the one-time prerequisites below.

| Stack | What it does | Provider |
| --- | --- | --- |
| `01-host` | Installs Docker Engine from Docker's official repo and creates `/srv/homelab` | built-in `terraform_data` + SSH |
| `02-ollama` | Runs Ollama in Docker (CPU-only) and pulls the models you list | [`kreuzwerker/docker`](https://search.opentofu.org/provider/kreuzwerker/docker) over SSH |

The stacks are separate because the Docker provider has to reach a running Docker daemon as soon as it starts, so Docker must already be installed when it runs.

## Prerequisites (one time)

1. **Install OpenTofu on the Mac.**

   ```bash
   brew install opentofu
   tofu version
   ```

2. **Set up SSH key login on the server.** If `~/.ssh/id_ed25519` doesn't exist, create it with `ssh-keygen -t ed25519`.

   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub user@IP
   ssh user@IP 'echo ok'   # must not ask for a password
   ```

   OpenTofu reads the key file directly, so the key can't have a passphrase. If yours has one, create a separate key for the homelab.

3. **Turn on passwordless sudo for that user** on the server. OpenTofu can't type a sudo password.

   ```bash
   ssh -t user@IP 'echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-homelab && sudo chmod 440 /etc/sudoers.d/90-homelab'
   ```

   > [!WARNING]
   > Anyone who has this SSH key gets root on the server. Keep the key on your Mac only.

4. **Create your variables file.**

   ```bash
   cd infra
   cp homelab.tfvars.example homelab.tfvars   # then edit host / ssh_user
   ```

   `homelab.tfvars` is git-ignored.

## Deploy

```bash
cd infra
make host     # installs Docker on the server
make ollama   # starts Ollama and pulls the models
```

Each command shows the plan and asks `yes` before changing anything. To preview without applying, run `make plan-ollama`.

After the first `init`, commit the `.terraform.lock.hcl` files so every run uses the same provider versions.

## Test

```bash
tofu -chdir=02-ollama output -raw test_command | sh
```

Or from any machine on the LAN:

```bash
curl http://192.168.1.50:11434/api/tags      # list models
```

Any app that speaks the Ollama API (Open WebUI, Continue, etc.) can use `http://<server-ip>:11434`.

## Models on this hardware

The server's GPU is an Intel HD Graphics 5500, which Ollama doesn't support, so inference runs on the CPU. The CPU has AVX2, which Ollama uses. Expect a few tokens per second from 3B models. Rough guide:

| Size | Examples | RAM needed | Speed |
| --- | --- | --- | --- |
| 1–2B | `qwen2.5:1.5b`, `qwen2.5-coder:1.5b`, `gemma3:1b` | ~2 GB | usable |
| 3–4B | `llama3.2:3b` (default), `gemma3:4b`, `qwen3:4b` | 3–4 GB | slow but OK |
| 7–8B | `llama3.1:8b`, `qwen2.5:7b` | 6–8 GB | very slow |

To change the list, edit `models` in `homelab.tfvars` and run `make ollama`:

```hcl
models = ["llama3.2:3b", "qwen2.5-coder:1.5b"]
```

Adding a name pulls that model. Removing a name deletes it from the server.

## Day-to-day

| Task | How |
| --- | --- |
| Update Ollama | `make ollama`. With `ollama_tag = "latest"`, a new image is pulled when the tag moves. Pin a version (`ollama_tag = "0.x.y"`) to update on your own schedule. |
| Cap RAM | `memory_limit_mb = 6144` in `homelab.tfvars` |
| Restrict to the server only | `bind_address = "127.0.0.1"` |
| Logs | `ssh user@<ip> docker logs -f ollama` |
| Remove Ollama | `make destroy-ollama`. Models stay in `/srv/homelab/ollama`. |

## Security notes

- The Ollama API has **no authentication**. With the default `bind_address = "0.0.0.0"`, anything on your LAN can use it. Never forward port 11434 on your router. For remote access, use a VPN such as Tailscale or WireGuard.
- State is kept locally in each stack (`terraform.tfstate`, git-ignored). It isn't secret today, but treat it as private.
