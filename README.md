# Codex Sandbox

Dockerized sandbox for running OpenAI Codex with a DinD (Docker-in-Docker) setup and optional Ansible provisioning.

## What This Repo Contains
- `Dockerfile` builds a Debian 13 image with Docker Engine, Compose plugin, and `@openai/codex`.
- `agent-sandbox.sh` starts/stops a sandbox container and lets you execute commands inside it.
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

Stop:
```bash
./agent-sandbox.sh stop
```

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