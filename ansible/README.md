# Ansible Debian 13 server bootstrap

This playbook provisions a Debian 13 server over SSH and installs:
- OpenSSH server (and enables it)
- VIM
- Docker Engine + Docker Compose plugin
- Predefined SSH public keys for the remote user

## Configure

1) Edit inventory with your host and user:

```
ansible/inventory.yml
```

2) Replace the placeholder SSH public keys:

```
ansible/group_vars/all.yml
```

## Run

From this directory:

```
cd ansible
ansible-playbook site.yml
```

## Notes

- Docker is installed from Docker's official Debian repo using the detected release (Debian 13 = trixie).
- The Compose plugin provides `docker compose` (recommended). If you need the legacy `docker-compose` binary, install it separately.
