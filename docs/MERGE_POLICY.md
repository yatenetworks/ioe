# Merge Policy

This policy describes how changes land on the default branch for IOE AI Env Installer.

## Branch rules

- Do not push directly to `main` for normal changes.
- All changes should go through a pull request.
- Maintainers may make urgent documentation fixes directly when necessary, but the default path is review before merge.

## Review expectations

Every pull request should have:

- a clear summary
- a stated risk level (low / medium / high)
- test notes when scripts, templates, or workflows change
- sign-off on commits when required by [DEVELOPER_CERTIFICATE_OF_ORIGIN.md](../DEVELOPER_CERTIFICATE_OF_ORIGIN.md)

## High-risk paths

Changes in the following paths require maintainer review before merge:

```text
install-ioe.sh
install.sh
scripts/
.github/workflows/
docs/MERGE_POLICY.md
docs/SECURITY_REVIEW_CHECKLIST.md
docs/RELEASE_CHECKLIST.md
SECURITY.md
templates/
examples/
module.yaml
docker-compose.yml
healthcheck.sh
```

Use [docs/CODE_REVIEW_CHECKLIST.md](CODE_REVIEW_CHECKLIST.md) and [docs/SECURITY_REVIEW_CHECKLIST.md](SECURITY_REVIEW_CHECKLIST.md) for these reviews.

## Do not merge

Reject or block merges that include:

- secrets, tokens, private keys, or real `.env` files
- obfuscated scripts or unexplained encoded payloads
- hidden network requests or undisclosed download steps
- destructive host operations without clear documentation and user consent
- content that violates [ACCEPTABLE_USE.md](../ACCEPTABLE_USE.md) or [THIRD_PARTY_POLICY.md](../THIRD_PARTY_POLICY.md)

## Installer status

`install-ioe.sh` should remain a safe public placeholder unless the repository README clearly states that a tested preview installer is active.

Do not merge installer changes that perform real system installation before clean VPS testing is documented.

## Automation

Pull requests are checked by [.github/workflows/pr-compliance.yml](../.github/workflows/pr-compliance.yml). Failed required checks should be resolved before merge.
