# SSH Box

A minimal Debian-based Docker container that provides:

* SSH access using public-key authentication only
* A bind-mounted host directory
* A non-root user (`sshbox`, UID 1000)
* Isolation from the local network and Internet using host firewall rules

The container is intended to provide a secure remote shell for accessing files in a mounted directory without allowing the container itself to initiate connections to the LAN or Internet.

## Get Started

`cp .env.example .env`

Then edit it to your preferences.

and run with 

`run.sh`

## Architecture

The container runs:

* Debian Bookworm Slim
* OpenSSH Server
* A normal user account (`sshbox`)
* Public-key authentication only

The host publishes:

```text
Host port 7723 -> Container port 22
```

allowing remote SSH access.

Unlike Docker's `internal: true` network mode, the container uses a normal bridge network. This is required because `internal: true` prevents Docker from publishing the SSH port.

Network isolation is instead enforced by firewall rules in Docker's `DOCKER-USER` chain.

## Why Not Use `internal: true`

Initially, the container used:

```yaml
networks:
  isolated:
    internal: true
```

This successfully blocked outbound network access but also prevented Docker from exposing the published SSH port.

The result was:

```text
PORTS
<empty>
```

in `docker ps`, making the container unreachable from other machines.

For this reason, the container uses a normal bridge network and relies on host firewall rules for outbound isolation.

## Directory Structure

```text
.
├── Dockerfile
├── docker-compose.yml
├── entry-point.sh
├── install-network-isolation.sh
├── remove-network-isolation.sh
```

## SSH Keys

Place one or more public SSH keys in `.ssh/authorized_keys` of the mounted home:

Password authentication is disabled.

## Build and Start

Build and start the container:

```bash
docker-compose up -d --build
```

## Connecting

From another machine:

```bash
ssh sshbox@10.0.0.2 -p 7723 -i ~/.ssh/private-key
```

Replace:

* `10.0.0.2` with the Docker host IP
* `private-key` with the private key corresponding to the public key in `authorized_keys`

## Isolation

### Goal

Allow:

* Incoming SSH connections

Block:

* Access to the Docker host
* Access to other LAN devices
* Access to the Internet
* Any outbound connections initiated by the container

### How It Works

Docker creates a bridge network with a dedicated subnet.

The isolation script installs firewall rules into Docker's built-in:

```text
DOCKER-USER
```

iptables chain.

The rules:

1. Allow packets belonging to established SSH sessions.
2. Drop all new outbound traffic originating from the Docker subnet.

As a result:

```text
Remote PC --> SSH Box
```

works,

while:

```text
SSH Box --> LAN
SSH Box --> Internet
SSH Box --> Docker Host
```

are blocked.

## Installing Isolation Rules

Run once after the container network has been created:

```bash
sudo ./install-network-isolation.sh
```

## When To Run install-network-isolation.sh

### Required

Run after:

* First deployment
* Host reboot (unless rules are made persistent)
* Changing the Docker subnet
* Modifying the isolation script

### Not Required

No need to run after:

* Container restart
* Container recreation
* Image rebuild
* `docker-compose up -d --build`

provided the Docker subnet remains unchanged.

## Removing Isolation

To remove all isolation rules:

```bash
sudo ./remove-network-isolation.sh
```

## Inspecting The Network

Show Docker networks:

```bash
docker network ls
```

The network name defaults to: `sshbox_isolated` or whatever value is configured in NETWORK_ISOLATED_NAME.

```bash
docker network inspect sshbox_isolated
```

Inspect firewall rules:

```bash
sudo iptables -L DOCKER-USER -n -v
```

Inspect Docker NAT rules:

```bash
sudo iptables -t nat -L -n -v
```

## Security Notes

The container:

* Does not permit password authentication.
* Does not permit root login.
* Uses SSH public keys only.
* Runs with a non-root user.
* Has outbound connectivity blocked by host firewall rules.

The mounted directory remains fully accessible to the SSH user and should therefore only contain files that are intended to be accessible through the SSH service.
