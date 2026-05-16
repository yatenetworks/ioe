# Application Template Policy

This document defines the basic rules for application templates supported by IOE AI Env Installer.

## Supported Application Types

Supported templates should be:

- Legal open-source applications
- Docker or Docker Compose based
- Reasonable for a normal VPS
- Documented clearly
- Suitable for local or self-hosted deployment

## Preferred Application Types

Good template candidates include:

- AI knowledge base tools
- RAG applications
- AI content tools
- AI assistant tools
- AI translation tools
- AI workflow tools
- Developer productivity tools
- Lightweight model or API utilities

## Basic Requirements

Each application template should include:

- Application name
- Source repository
- License
- Required ports
- Required environment variables
- Minimum recommended CPU and RAM
- Storage paths
- Backup notes
- Basic health check notes

## Storage Requirement

All persistent application data must be stored under:

```text
~/ioe-data/apps/<app_name>/
```

Backups must be stored under:

```text
~/ioe-data/backups/<app_name>/
```

Models should be stored under:

```text
~/ioe-data/models/
```

Avoid unnamed Docker volumes unless there is a clear reason.

## Environment Variables

Templates must not include real secrets.

Do not hardcode:

- API keys
- Passwords
- Tokens
- Private URLs
- Cloud credentials
- SSH keys

Use placeholders instead.

Example:

```env
OPENAI_API_KEY=change-me
DATABASE_PASSWORD=change-me
```

## Port Rules

Templates must clearly document exposed ports.

Avoid exposing internal services such as databases, caches, or message queues directly to the public Internet.

If an application needs public access, prefer a reverse proxy.

## Security Rules

Templates should avoid:

- Privileged containers unless absolutely necessary
- Host networking unless clearly justified
- Unrestricted volume mounts
- Hardcoded admin passwords
- Public database ports
- Unsafe default credentials

## Not Accepted

Templates should not include:

- Malware
- Phishing tools
- Credential theft tools
- Unauthorized scraping tools
- Adult or pornographic services
- Gambling services
- Copyright-infringing services
- Applications without clear license permission
- Applications that collect user data without disclosure

## Review Notes

Before adding a template, check:

- License
- Resource usage
- Docker Compose safety
- Port exposure
- Data paths
- Backup behavior
- Basic startup behavior

Templates should be simple, predictable, and easy to remove.