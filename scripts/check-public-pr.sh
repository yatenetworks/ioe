#!/usr/bin/env bash
# Public PR checks (no root, no Docker). Aligns with .github/workflows/pr-compliance.yml.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

failures=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

echo "== IOE public PR checks =="
echo "Repo root: ${ROOT}"
echo

# --- bash -n ---
echo "-- Shell syntax (bash -n) --"
shell_files=(
  install-ioe.sh
  install.sh
  public-runnable-preview/install-ioe.sh
  public-runnable-preview/scripts/test-ioectl-lifecycle.sh
  scripts/check-public-pr.sh
  scripts/check-template-lifecycle.sh
)
while IFS= read -r -d '' f; do
  shell_files+=("$f")
done < <(find public-runnable-preview/templates/modules -type f \( -name '*.sh' \) -print0 2>/dev/null || true)

for f in "${shell_files[@]}"; do
  if [[ -f "${f}" ]]; then
    if bash -n "${f}"; then
      pass "bash -n ${f}"
    else
      fail "bash -n ${f}"
    fi
  fi
done
echo

# --- Python compile ---
echo "-- Python compile --"
if compgen -G "public-runnable-preview/tools/*.py" >/dev/null; then
  if python3 -m py_compile public-runnable-preview/tools/*.py; then
    pass "py_compile public-runnable-preview/tools/*.py"
  else
    fail "py_compile public-runnable-preview/tools/*.py"
  fi
else
  fail "no Python tools found under public-runnable-preview/tools/"
fi
echo

# --- ioectl validate all module manifests ---
echo "-- ioectl validate (module manifests) --"
preview="${ROOT}/public-runnable-preview"
if [[ ! -x "${preview}/ioectl" ]]; then
  fail "missing executable ${preview}/ioectl"
else
  pushd "${preview}" > /dev/null
  if [[ -d .venv ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
  fi
  shopt -s nullglob
  modules=(templates/modules/*/module.yaml)
  if [[ ${#modules[@]} -eq 0 ]]; then
    fail "no templates/modules/*/module.yaml found"
  else
    for yaml in "${modules[@]}"; do
      if ./ioectl validate module "${yaml}"; then
        pass "validate ${yaml}"
      else
        fail "validate ${yaml}"
      fi
    done
  fi
  popd > /dev/null
fi
echo

# --- Public-safe wording (PR Compliance) ---
echo "-- Public-safe wording --"
WORD_PATTERN='distributed runtime|scheduler|marketplace|identity|settlement|federation|native protocol|machine-to-machine|cellular|next-generation|global AI network|node economy|蜂窝|节点经济|身份|联邦|下一代|机器间|协议费|控制面板|面板'
WORD_PATHS=(
  README.md
  docs
  examples
  install-ioe.sh
  install.sh
  CODE_OF_CONDUCT.md
  ACCEPTABLE_USE.md
  CONTRIBUTOR_TERMS.md
  DEVELOPER_CERTIFICATE_OF_ORIGIN.md
  THIRD_PARTY_POLICY.md
  .github
  public-runnable-preview
  scripts
)
word_hits=""
word_hits="$(grep -RInE "${WORD_PATTERN}" \
  --exclude='pr-compliance.yml' \
  --exclude='RELEASE_CHECKLIST.md' \
  --exclude='check-public-pr.sh' \
  --exclude-dir=.venv \
  "${WORD_PATHS[@]}" 2>/dev/null || true)"
if [[ -n "${word_hits}" ]]; then
  fail "disallowed public wording found"
  echo "${word_hits}" >&2
else
  pass "no disallowed public wording"
fi
echo

# --- Secret-like patterns ---
echo "-- Secret-like patterns --"
SECRET_PATTERN='(AKIA[0-9A-Z]{16})|(BEGIN (RSA |OPENSSH )?PRIVATE KEY)|(ghp_[A-Za-z0-9]{20,})|(github_pat_[A-Za-z0-9_]{20,})|(xox[baprs]-[A-Za-z0-9-]{10,})'
secret_hits=""
secret_hits="$(grep -RInE "${SECRET_PATTERN}" \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude-dir=node_modules \
  . 2>/dev/null || true)"
if [[ -n "${secret_hits}" ]]; then
  fail "possible secret pattern detected"
  echo "${secret_hits}" >&2
else
  pass "no secret-like patterns"
fi
echo

# --- Summary ---
if [[ "${failures}" -eq 0 ]]; then
  echo "== RESULT: PASS (all checks) =="
  exit 0
else
  echo "== RESULT: FAIL (${failures} check(s) failed) =="
  exit 1
fi
