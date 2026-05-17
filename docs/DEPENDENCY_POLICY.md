# Dependency Policy

IOE aims to stay small and easy to audit. New dependencies should be rare and well justified.

## When to add a dependency

Add a dependency only when:

- existing tools in the repo cannot solve the problem cleanly
- the license is compatible with the project
- the source is trustworthy and actively maintained
- the pull request explains purpose, version, and update plan

## Required PR information

For each new dependency, document:

- name and version (or image tag)
- license
- why it is needed
- how it is updated or pinned
- any security or supply-chain notes

## Not allowed

Do not add:

- suspicious or typosquatted packages
- unknown prebuilt binaries without checksum and source link
- dependencies downloaded from unversioned URLs
- vendored code copied without license and attribution
- dependencies that phone home without clear documentation

## Container images

Template `docker-compose.yml` files should prefer:

- official or widely trusted images
- explicit image tags (not only `latest`)
- documented purpose for each service

Avoid obscure registries unless the pull request explains the trust model.

## Removal

Prefer removing unused dependencies in the same area you are already changing, but do not expand scope unnecessarily.

Maintainers may reject dependency additions that make the repository harder to review or harder to run on a clean Linux server.
