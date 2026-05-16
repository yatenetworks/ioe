# IOE AI Env Installer

> Install AI application environments on IOE.

IOE AI Env Installer, short for **IOE AI Application Environment Installer**, is a lightweight open-source tool for setting up AI application environments on clean Linux servers.

It helps prepare a Docker-based server environment with predictable storage, basic security defaults, and simple runtime diagnostics.

## What This Tool Does

IOE AI Env Installer helps with:

- Basic Linux server checks
- Docker and Docker Compose setup
- Standardized application data directories
- Basic firewall configuration
- Health checks
- Backup and restore structure
- Simple command-line management through `ioectl`

## Project Scope

This project is a deployment tool.

It focuses on:

- Clean Linux server setup
- Docker-based AI application environments
- Predictable storage paths
- Basic security defaults
- Repeatable installation
- Backup-friendly application layout

This project does not provide hosting services, managed cloud services, public infrastructure services, or production guarantees.

## Important Usage Notice

This tool is intended for **fresh and clean Linux systems only**.

Do not run it on servers that already host production services, custom Docker stacks, databases, panels, or complex existing configurations.

Using this tool on an old or busy server may cause conflicts, failed deployments, port issues, or service interruption.

You are responsible for reviewing the script before running it.

## Requirements

Recommended environment:

- Fresh Linux server
- Root or sudo access
- Docker-compatible system
- At least 2 GB RAM
- At least 10 GB free disk space
- Stable network access

Supported Linux distributions may vary during beta testing.

## Standard Data Layout

IOE AI Env Installer uses a predictable data layout:

```text
~/ioe-data/
├── apps/
│   └── <app_name>/
├── backups/
│   └── <app_name>/
└── models/
```

Application data should be placed under:

```text
~/ioe-data/apps/<app_name>/
```

Backups should be placed under:

```text
~/ioe-data/backups/<app_name>/
```

Models should be placed under:

```text
~/ioe-data/models/
```

This structure keeps application files, backups, and runtime data easier to understand and migrate.

## Installation

The installer script name is:

```text
install-ioe.sh
```

The command-line tool is:

```text
ioectl
```

Installation command:

```bash
bash install-ioe.sh
```

Remote installation command:

```bash
curl -fsSL https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh | bash
```

Review the script before running it on your server.

## Basic Commands

Run diagnostics:

```bash
ioectl doctor
```

Check status:

```bash
ioectl status
```

View logs:

```bash
ioectl logs
```

Check security hints:

```bash
ioectl security
```

Show local runtime status:

```bash
ioectl runtime
```

## Security Notes

This tool does not modify your SSH configuration by default.

Port `22` remains reachable to avoid accidental lockout.

Before using the server for anything important, review:

```bash
ioectl security
```

You should also review your cloud provider firewall or security group settings.

## Clean System Requirement

This tool should only be used on a fresh Linux server.

Do not use it on:

- Existing production servers
- Servers already running important Docker containers
- Servers with custom firewall rules you do not understand
- Servers with existing panels or complex service stacks
- Servers without backup or recovery access

## Application Template Policy

Only legal and properly licensed open-source applications should be added.

Application templates should:

- Use Docker or Docker Compose
- Have a clear open-source license
- Avoid hardcoded secrets
- Store data under `~/ioe-data/apps/<app_name>/`
- Document required ports and resources
- Avoid exposing databases or internal services directly to the public Internet

See:

```text
docs/APP_TEMPLATE_POLICY.md
```

## Application template draft

IOE is preparing a simple, validation-friendly format for AI application environment templates.

Current draft files:

- [Module manifest draft](docs/MODULE_MANIFEST_DRAFT.md)
- [Template validation](docs/TEMPLATE_VALIDATION.md)
- [Example AI module manifest](examples/ai-module.example.yaml)
- [Local module runtime preview](docs/LOCAL_MODULE_RUNTIME_PREVIEW.md)
- [Example local module template](examples/local-module-template.example.yaml)

These drafts are early and may change.

The goal is to make AI application environment templates easier to review, validate, install, back up, and maintain.

## Current Status

This project is in beta.

Use it for testing, development, and clean server setup experiments.

Do not assume production readiness without your own review, testing, and backup plan.

## Community

IOE AI Env Installer is still in an early public beta stage.

We will continue to improve the installer, documentation, compatibility checks, and application templates in public.

Early feedback is especially valuable. Testing on different Linux servers, reporting issues, improving documentation, and contributing Docker Compose templates can directly help make the tool more reliable for others.

This project is intended to grow through practical open-source collaboration.

## Disclaimer

This project is provided as an open-source tool without warranty.

You are responsible for:

- Reviewing the code
- Understanding what the installer changes
- Backing up your data
- Securing your server
- Testing compatibility with your system
- Using the tool legally and responsibly

The maintainers are not responsible for data loss, service interruption, security issues, configuration mistakes, or any damage caused by improper use.