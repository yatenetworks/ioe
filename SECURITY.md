# Security Policy

IOE AI Env Installer is a server setup tool. Security matters because the tool may configure Docker, firewall rules, application directories, and local runtime services.

## Supported Use

This project is intended for fresh Linux servers.

Do not run it on existing production servers unless you have reviewed the script, tested it, and prepared a backup and rollback plan.

## Reporting Security Issues

Please do not disclose security vulnerabilities in public issues.

If you find a security problem, report it privately to the maintainer.

Include:

- A clear description of the issue
- Steps to reproduce
- Affected files or commands
- Possible impact
- Suggested fix, if available

## Security Defaults

The installer is designed to follow conservative defaults:

- Do not modify SSH configuration by default
- Do not close port `22` by default
- Do not overwrite an existing Docker daemon configuration
- Do not reset an existing firewall rule set
- Do not store user API keys in source code
- Do not commit `.env` files
- Keep optional extension features disabled by default

## Docker Socket Warning

If the backend or panel mounts:

```text
/var/run/docker.sock
```

it can control the host Docker engine.

Do not expose any API with Docker socket access to the public Internet without authentication and proper access control.

## Secrets

Never commit:

- API keys
- Cloud credentials
- SSH private keys
- Database passwords
- `.env` files
- User data directories

Use environment variables or user-provided configuration.

## Firewall and Cloud Security Groups

The installer may configure local firewall rules.

Your cloud provider may also have a separate firewall or security group.

You are responsible for checking both:

- Server firewall
- Cloud provider firewall or security group

## Clean Server Requirement

For safety, use a fresh Linux server.

Avoid running the installer on servers with:

- Existing production workloads
- Important Docker containers
- Custom networking rules
- Existing panels
- Unknown system state

## No Warranty

This project is provided without warranty.

Use it at your own risk.