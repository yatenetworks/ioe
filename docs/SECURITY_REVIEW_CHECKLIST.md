# Security Review Checklist

Use this checklist when reviewing shell scripts, installers, workflows, templates, and any change that touches the host or network.

## Scripts and installers

- [ ] `bash -n` passes for changed shell scripts.
- [ ] No `curl ... | bash` or `wget ... | sh` patterns without clear documentation and user consent.
- [ ] No unexplained remote downloads or checksum bypass.
- [ ] No broad `rm -rf` against system paths, home directories, or `/`.
- [ ] No `chmod 777` or world-writable sensitive paths.
- [ ] No silent `sudo`, forced root assumptions, or privilege escalation without clear need.
- [ ] Installer changes do not enable real system installation unless README and release notes say preview is tested.

## Containers and host access

- [ ] No Docker socket mount (`/var/run/docker.sock`) unless strictly required and documented.
- [ ] No `privileged: true`, `cap_add: ALL`, or host PID/network namespace without justification.
- [ ] Published ports are documented; databases and queues are not exposed publicly by default.
- [ ] Volume mounts do not overwrite unexpected host paths.

## Workflows and automation

- [ ] GitHub Actions use least privilege and pinned action versions where practical.
- [ ] Workflows do not echo secrets or write credentials to logs.
- [ ] Third-party actions are from known sources and justified in the PR.

## Templates

- [ ] `.env.example` uses placeholders only; no real secrets.
- [ ] Health checks do not leak credentials in URLs or headers.
- [ ] Logs do not print tokens or passwords.
- [ ] `remove` behavior does not delete persistent user data by default.

## Data and privacy

- [ ] No collection of user data beyond what is needed for local operation.
- [ ] No hidden telemetry or outbound calls without documentation.

## Red flags

Stop review and request changes if you see:

- obfuscated code or base64 payloads without explanation
- secret patterns (API keys, private keys, cloud tokens)
- destructive operations disguised as documentation edits
- copy-paste from restricted internal systems
