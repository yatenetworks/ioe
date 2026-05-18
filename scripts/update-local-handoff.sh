#!/usr/bin/env bash
# Update local-only session handoff file (never commit LOCAL_SESSION_HANDOFF.md).
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="${ROOT}/LOCAL_SESSION_HANDOFF.md"
TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

cd "${ROOT}"

if ! git check-ignore -q "LOCAL_SESSION_HANDOFF.md" 2>/dev/null; then
  echo "ERROR: LOCAL_SESSION_HANDOFF.md is not gitignored; refusing to write" >&2
  exit 1
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
COMMIT="$(git log -1 --oneline 2>/dev/null || echo 'no commits')"
STATUS="$(git status --short 2>/dev/null || true)"
LOG="$(git log -8 --oneline 2>/dev/null || true)"
CHANGED="$(git diff --stat HEAD 2>/dev/null || true)"
if [[ -z "${CHANGED}" ]]; then
  CHANGED="(no diff vs HEAD)"
fi

cat > "${HANDOFF}" <<EOF
# Local session handoff (do not commit)

Updated: ${TIMESTAMP}

## Repo path

${ROOT}

## Branch

${BRANCH}

## Latest commit

${COMMIT}

## Git status --short

\`\`\`
${STATUS}
\`\`\`

## Last 8 commits

\`\`\`
${LOG}
\`\`\`

## Changed files summary (vs HEAD)

\`\`\`
${CHANGED}
\`\`\`

## Suggested next step

<!-- Cursor: replace with concrete next safe action after this task -->

- Review open PR / Bugbot / CI
- Run \`scripts/check-public-pr.sh\` before merge
- Update Bugbot/CI status and unresolved risks here

## Notes (optional)

- tests/checks run:
- open PR:
- Bugbot/CI:
- unresolved risks:

EOF

echo "Updated LOCAL_SESSION_HANDOFF.md"
