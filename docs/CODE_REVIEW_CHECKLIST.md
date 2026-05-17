# Code Review Checklist

Use this checklist for documentation, examples, and general repository changes.

## Scope and clarity

- [ ] The change has a clear purpose tied to AI application environment templates or public standards.
- [ ] The pull request description explains what changed and why.
- [ ] The diff is focused and avoids unrelated cleanup.
- [ ] Naming and structure match existing project conventions.

## Documentation

- [ ] README or docs are updated when behavior or expectations change.
- [ ] Links point to files that exist in the repository.
- [ ] Examples remain copy-friendly and low-risk.
- [ ] No secrets, real credentials, or user data paths are introduced.

## Compatibility and stability

- [ ] Changes do not break the documented lifecycle without an explicit note.
- [ ] Data path conventions (`~/ioe-data/...`) remain consistent.
- [ ] Remove/stop behavior still preserves user data by default unless clearly documented otherwise.
- [ ] Automation-friendly output examples remain valid JSON or stable text where applicable.

## Templates and examples

- [ ] Example YAML and Compose files follow [MODULE_TEMPLATE_STANDARD.md](MODULE_TEMPLATE_STANDARD.md).
- [ ] Template-specific changes also use [TEMPLATE_REVIEW_CHECKLIST.md](TEMPLATE_REVIEW_CHECKLIST.md).

## Process

- [ ] Commits include `Signed-off-by` when required.
- [ ] Risk level is stated in the pull request template.
- [ ] High-risk paths are called out for maintainer review per [MERGE_POLICY.md](MERGE_POLICY.md).
