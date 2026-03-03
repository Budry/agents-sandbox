# Codex Sandbox

Dockerized sandbox for running OpenAI Codex with a DinD (Docker-in-Docker) setup and optional Ansible provisioning.

## What This Repo Contains
- `Dockerfile` builds a Debian 13 image with Docker Engine, Compose plugin, `@openai/codex`, and `@anthropic-ai/claude-code`.
- `agent-sandbox.sh` starts/stops a sandbox container, executes commands inside it, and prints auto-generated public URLs.
- `scripts/` contains helpers for single-session docker registry auth when pulling/pushing images.
- `ansible/` provisions a Debian 13 server and installs required dependencies.

## Requirements
- Docker Engine and Docker Compose plugin on the host.
- Access to the private registry `docker-registry.zaruba-ondrej.dev` if you build/push the image.

## Build And Push The Image
```bash
make build
```

## Run The Sandbox Locally
Start:
```bash
./agent-sandbox.sh start ~/.codex/config.toml ~/.ssh/id_ed25519
```

Exec a command:
```bash
./agent-sandbox.sh exec codex
```

List generated public URLs:
```bash
./agent-sandbox.sh urls
```

Stop:
```bash
./agent-sandbox.sh stop
```

## Automatic Public URLs
Every running HTTP container inside the sandbox gets an automatic URL in:
`http://<random>.agents-sandbox.zaruba-ondrej.dev`

The ingress is started automatically by the sandbox and updates routes every few seconds.
Make sure DNS wildcard `*.agents-sandbox.zaruba-ondrej.dev` points to the sandbox host IP.
Sandbox always binds public ports `80` and `443`.

Optional overrides:
- `INGRESS_BASE_DOMAIN` (default: `agents-sandbox.zaruba-ondrej.dev`)

## Ansible Provisioning
Inventory is in `ansible/inventory.yml`, playbook in `ansible/site.yml`.

Run:
```bash
ansible-playbook -i ansible/inventory.yml ansible/site.yml
```

The playbook:
- Installs Docker and base packages on Debian 13.
- Pulls the sandbox image from the registry using a one-time login.
- Installs `agent-sandbox` and helper scripts.
- Copies the `.codex` config to the remote user.

## Helper Scripts
One-time registry login for a single pull:
```bash
./scripts/docker-pull-session.sh docker-registry.zaruba-ondrej.dev/my/image:tag
```

One-time registry login for a single push:
```bash
./scripts/docker-push-session.sh docker-registry.zaruba-ondrej.dev/my/image:tag
```
