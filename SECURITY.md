# Security Policy

IOE AI Env Installer is intended to help standardize AI application environment templates. Security matters because templates may define containers, ports, data paths, environment variables, and local lifecycle behavior.

## Current public status

The public installer is not active yet.

`install-ioe.sh` currently exits safely and does not modify the system. It is kept as a stable future entry name while the project focuses on public documentation, template standards, and clean-server testing.

## Supported use

Use this repository for:

- reviewing public template standards
- discussing module manifest structure
- contributing safe examples
- testing local preview behavior when a tested preview installer is released

Do not assume production readiness.

## Reporting security issues

Please do not disclose security vulnerabilities in public issues.

If you find a security problem, report it privately to the maintainer.

Include:

- a clear description of the issue
- steps to reproduce
- affected files or commands
- possible impact
- suggested fix, if available

## Secrets

Never commit:

- API keys
- cloud credentials
- SSH private keys
- database passwords
- `.env` files
- user data directories

Use `.env.example` with placeholders.

## Docker socket warning

A container or service with access to:

```text
/var/run/docker.sock
```

can control the host Docker engine.

Templates should avoid Docker socket access unless strictly required and clearly documented.

## Port exposure

Templates should not expose databases, caches, queues, or internal control APIs directly to the public Internet by default.

All public ports should be clearly documented.

## Clean server requirement

When an active installer is released, it should be tested on a fresh Linux server first.

Avoid running experimental install scripts on servers with:

- existing production workloads
- important Docker containers
- custom networking rules
- unknown system state
- data without backups

## No warranty

This project is provided without warranty.

Use it at your own risk.
