# Compatibility report guide

A **compatibility report** records whether an IOE AI application environment template works on a specific OS, hardware, and Docker setup.

Reports support the **local runnable preview** and **testing preview** work. They are not production certifications or uptime guarantees.

## Why reports matter

- Help maintainers decide whether a template is **tested** or **verified**
- Document known limitations for self-hosted users
- Reduce repeated “does it work on my VPS?” questions
- Complement pull request test notes with a public, searchable record

File reports using the GitHub **Compatibility report** issue template.

## What to include

Provide as much of the following as possible:

| Item | Example |
|------|---------|
| Template name | `hello.basic` or community module id |
| IOE version or commit | branch name + short SHA |
| OS and version | Ubuntu 24.04 LTS |
| Kernel (optional) | `uname -r` |
| CPU / RAM | 2 vCPU, 2 GB RAM, 2 GB swap |
| Docker version | `docker --version` |
| Compose version | `docker compose version` |
| VPS or provider (optional) | provider + instance type |
| Commands run | see lifecycle list below |
| Result | passed / failed / partial |
| Error logs | redacted; no secrets |
| Cleanup | whether `remove` left user data in place |

## Lifecycle commands

A successful report should include **all** lifecycle commands where possible:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

Note any step that was skipped and why.

## Output summary

Briefly state:

- which steps passed or failed
- whether HTTP health checks responded
- whether ports were reachable only on localhost
- whether `module remove` stopped containers without deleting persistent data under `IOE_DATA_DIR` (or documented data paths)

Paste relevant log excerpts in the issue. Do not include API keys, tokens, or private hostnames you do not want public.

## Supported OS targets (preview)

The local runnable preview installer has been exercised on:

- Debian 12
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

Reports on other distributions are welcome but may be marked as **informational** until maintainers can reproduce.

## After you file a report

Maintainers may:

- ask for a follow-up test on another OS
- link the report to a template contribution pull request
- update template README limitations
- keep the template in **draft** or mark it **tested** / **verified** when criteria in [AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md](AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md) are met

A single failed report does not automatically remove a template; it documents known constraints for the community.
