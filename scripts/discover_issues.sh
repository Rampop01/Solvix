#!/usr/bin/env bash
# =============================================================================
# Solvix — Auto-Discover Issues assigned to you by a specific person
# =============================================================================
# Usage:
#   ./scripts/discover_issues.sh --repo owner/repo --assigned-by github-username
#
# Example:
#   ./scripts/discover_issues.sh --repo Gildado/payd --assigned-by Gildado
#
# What it does:
#   1. Resolves YOUR GitHub username from the PAT
#   2. Fetches all open issues in the repo assigned to you
#   3. Filters for issues created by --assigned-by
#   4. Prints the issue list and the exact run_multi.sh command to fix them all
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[discover]${RESET} $*"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
die()  { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
REPO=""
ASSIGNED_BY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         REPO="$2";        shift 2 ;;
    --assigned-by)  ASSIGNED_BY="$2"; shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -z "$REPO" ]]        && die "--repo is required (e.g. --repo Gildado/payd)"
[[ -z "$ASSIGNED_BY" ]] && die "--assigned-by is required (e.g. --assigned-by Gildado)"
[[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] && \
  die "GITHUB_PERSONAL_ACCESS_TOKEN is not set."

REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# ── Resolve who YOU are ───────────────────────────────────────────────────────
log "Resolving your GitHub username..."
MY_USERNAME=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])") \
  || die "Could not resolve your GitHub username. Check your PAT."
ok "Logged in as: ${BOLD}${MY_USERNAME}${RESET}"

# ── Fetch all open issues assigned to you ────────────────────────────────────
log "Fetching open issues in ${REPO} assigned to ${MY_USERNAME}..."

ISSUES_JSON=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&assignee=${MY_USERNAME}&per_page=100") \
  || die "Could not fetch issues. Check that the repo exists and your PAT has 'repo' scope."

# ── Filter: created by ASSIGNED_BY, exclude pull requests ────────────────────
ISSUE_DATA=$(echo "$ISSUES_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assigned_by = '${ASSIGNED_BY}'.lower()
results = []
for issue in data:
    if 'pull_request' in issue:
        continue
    if issue.get('user', {}).get('login', '').lower() == assigned_by:
        results.append({
            'number': issue['number'],
            'title':  issue['title'],
            'url':    issue['html_url']
        })
print(json.dumps(results))
")

COUNT=$(echo "$ISSUE_DATA" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

# ── Output ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Solvix — Issues assigned to you by ${ASSIGNED_BY}      ${RESET}"
echo -e "${BOLD}  Repo: ${REPO}${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

if [[ "$COUNT" -eq 0 ]]; then
  warn "No open issues found in ${REPO} assigned to ${MY_USERNAME} and created by ${ASSIGNED_BY}."
  echo ""
  echo "  Possible reasons:"
  echo "  · The issues were assigned by someone else"
  echo "  · All matching issues are already closed"
  echo "  · The repo name or --assigned-by username is wrong"
  echo ""
  exit 0
fi

ok "Found ${COUNT} issue(s) to fix:"
echo ""

echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i, issue in enumerate(data, 1):
    print(f\"  [{i}] #{issue['number']} — {issue['title']}\")
    print(f\"       {issue['url']}\")
    print()
"

NUMBERS=$(echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(' '.join(str(i['number']) for i in data))
")

echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Fix all ${COUNT} issues in one PR — run this:${RESET}"
echo ""
echo -e "  ${CYAN}./scripts/run_multi.sh --repo ${REPO} --assigned-by ${ASSIGNED_BY}${RESET}"
echo ""
