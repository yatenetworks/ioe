# Release Checklist

Use this checklist before tagging a release or announcing installer readiness.

## Script syntax

```bash
bash -n install-ioe.sh install.sh
```

Both commands should complete without syntax errors.

## Public messaging scan

Search for outdated or internal wording in public paths:

```bash
grep -RInE "distributed runtime|scheduler|marketplace|identity|settlement|federation|native protocol|machine-to-machine|cellular|next-generation|global AI network|node economy|蜂窝|节点经济|身份|联邦|下一代|机器间|协议费|控制面板|面板" \
  README.md docs examples install-ioe.sh install.sh \
  CODE_OF_CONDUCT.md ACCEPTABLE_USE.md CONTRIBUTOR_TERMS.md \
  DEVELOPER_CERTIFICATE_OF_ORIGIN.md THIRD_PARTY_POLICY.md .github || true
```

Investigate any unexpected matches before release.

## Installer status

- [ ] `install-ioe.sh` still matches the README description.
- [ ] If the installer is still inactive, confirm it does not install packages, download code, start containers, change firewall rules, create users, or modify the host.
- [ ] Enable real installer behavior only after clean VPS testing is documented.

## Secrets and local artifacts

Confirm the release tree does not include:

- `.env` files with real values
- API tokens or private keys
- `venv/`, `node_modules/`, cache directories, or local test data
- `~/ioe-data` copies or user exports

## Documentation consistency

- [ ] README matches current public status.
- [ ] `docs/` lifecycle and path conventions match examples.
- [ ] Example module YAML and Compose files still validate conceptually.
- [ ] SECURITY.md and governance docs reflect current process.

## Tags

- [ ] Create a git tag only for a real milestone.
- [ ] Do not tag routine documentation edits unless maintainers agree it is a release point.
- [ ] Write release notes that state installer active/inactive status clearly.

## Post-release

- [ ] Watch for security reports and broken links.
- [ ] Monitor failed compliance workflows on new pull requests.
