#!/usr/bin/env bash
# =============================================================================
# Solvix — Multi-Issue Fix (one PR closes all assigned issues)
# =============================================================================
# Usage:
#   ./scripts/run_multi.sh --repo owner/repo --assigned-by github-username
#
# Example:
#   ./scripts/run_multi.sh --repo Gildado/payd --assigned-by Gildado
#
# What it does:
#   1. Auto-discovers all open issues assigned to you by --assigned-by
#   2. Creates ONE branch: fix/issues-<N1>-<N2>-<N3>...
#   3. Runs the Solvix orchestrator for each issue on that same branch
#   4. Opens ONE PR to the parent repo that closes ALL issues
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[solvix]${RESET} $*"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
die()  { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
REPO=""
ASSIGNED_BY=""
TEST_CMD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         REPO="$2";        shift 2 ;;
    --assigned-by)  ASSIGNED_BY="$2"; shift 2 ;;
    --test-cmd)     TEST_CMD="$2";    shift 2 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -z "$REPO" ]]        && die "--repo is required (e.g. --repo Gildado/payd)"
[[ -z "$ASSIGNED_BY" ]] && die "--assigned-by is required (e.g. --assigned-by Gildado)"
[[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] && \
  die "GITHUB_PERSONAL_ACCESS_TOKEN is not set."

REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# ── Step 1: Resolve your GitHub username ─────────────────────────────────────
log "Resolving your GitHub username..."
MY_USERNAME=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])") \
  || die "Could not resolve your GitHub username. Check your PAT."
ok "Logged in as: ${BOLD}${MY_USERNAME}${RESET}"

# ── Step 2: Discover all issues assigned to you by ASSIGNED_BY ───────────────
log "Discovering open issues in ${REPO} assigned to you by ${ASSIGNED_BY}..."

ISSUES_JSON=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&assignee=${MY_USERNAME}&per_page=100") \
  || die "Could not fetch issues. Check repo name and PAT permissions."

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
            'url':    issue['html_url'],
            'body':   issue.get('body') or ''
        })
print(json.dumps(results))
")

COUNT=$(echo "$ISSUE_DATA" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
NUMBERS=$(echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(' '.join(str(i['number']) for i in data))
")
NUMBERS_DASHED=$(echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('-'.join(str(i['number']) for i in data))
")

# ── Print discovered issues ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Solvix — Multi-Issue Fix                             ${RESET}"
echo -e "${BOLD}  Repo: ${REPO} | Assigned by: ${ASSIGNED_BY}         ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

if [[ "$COUNT" -eq 0 ]]; then
  warn "No open issues found assigned to ${MY_USERNAME} by ${ASSIGNED_BY} in ${REPO}."
  echo ""
  echo "  Run ./scripts/discover_issues.sh to debug."
  exit 0
fi

ok "Found ${COUNT} issue(s) to fix:"
echo ""
echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i, issue in enumerate(data, 1):
    print(f\"  [{i}] #{issue['number']} — {issue['title']}\")
"
echo ""

BRANCH="fix/issues-${NUMBERS_DASHED}"
export AGENT_REPO="$REPO"
export AGENT_REPO_OWNER="$REPO_OWNER"
export AGENT_REPO_NAME="$REPO_NAME"
export AGENT_FORK_OWNER="$MY_USERNAME"
export AGENT_BRANCH="$BRANCH"
export AGENT_TEST_CMD="${TEST_CMD:-AUTO}"
export AGENT_ISSUE_NUMBERS="$NUMBERS"
export AGENT_ASSIGNED_BY="$ASSIGNED_BY"
export AGENT_ISSUE_DATA="$ISSUE_DATA"

# ── Print run configuration ───────────────────────────────────────────────────
echo -e "${BOLD}Run configuration:${RESET}"
echo -e "  Repo         : ${CYAN}${REPO}${RESET}"
echo -e "  Issues       : ${CYAN}#$(echo $NUMBERS | tr ' ' ',')${RESET}"
echo -e "  Branch       : ${CYAN}${BRANCH}${RESET}"
echo -e "  Fork owner   : ${CYAN}${MY_USERNAME}${RESET}"
echo -e "  PR strategy  : ${CYAN}ONE PR closing all ${COUNT} issues${RESET}"
echo -e "  Test command : ${CYAN}${AGENT_TEST_CMD}${RESET}"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── Instructions for Bob ──────────────────────────────────────────────────────
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo "  1. Open IBM Bob 2.0 in this directory (already open? stay here)."
echo "  2. Switch to Agent mode."
echo "  3. Open agent/multi_orchestrator.md"
echo "  4. The following variables are pre-loaded for this session:"
echo ""
echo "       REPO=$REPO"
echo "       ISSUE_NUMBERS=$NUMBERS"
echo "       BRANCH=$BRANCH"
echo "       FORK_OWNER=$MY_USERNAME"
echo "       TEST_CMD=${AGENT_TEST_CMD}"
echo "       ASSIGNED_BY=$ASSIGNED_BY"
echo ""
echo "  5. Hit run — Solvix will fix all ${COUNT} issues and open ONE PR"
echo "     that closes: $(echo $NUMBERS | sed 's/ /, #/g' | sed 's/^/#/')"
echo ""
log "Ready. Open agent/multi_orchestrator.md in Bob → Agent mode."
