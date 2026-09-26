#!/usr/bin/env bash
# =============================================================================
# Solvix — Multi-Issue Fix (one PR closes all assigned issues)
# =============================================================================
# Usage:
#   ./scripts/run_multi.sh --repo owner/repo
#   ./scripts/run_multi.sh --repo owner/repo --assigned-by github-username
#
# If --assigned-by is omitted, Solvix auto-detects the assigner from GitHub.
# If issues come from multiple people, you will be prompted to choose.
#
# Optional:
#   --test-cmd  "pytest"   (default: AUTO)
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

[[ -z "$REPO" ]] && die "--repo is required (e.g. --repo Gildado/PayD)"
[[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] && \
  die "GITHUB_PERSONAL_ACCESS_TOKEN is not set."

REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# ── Step 1: Resolve your GitHub username ──────────────────────────────────────
log "Resolving your GitHub username..."
MY_USERNAME=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])") \
  || die "Could not resolve your GitHub username. Check your PAT."
ok "Logged in as: ${BOLD}${MY_USERNAME}${RESET}"

# ── Step 2: Fetch all open issues assigned to you ─────────────────────────────
log "Fetching open issues in ${REPO} assigned to you..."
ISSUES_JSON=$(curl -sf \
  -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=open&assignee=${MY_USERNAME}&per_page=100") \
  || die "Could not fetch issues. Check repo name and PAT permissions."

# ── Step 3: Auto-detect or filter by assigner ────────────────────────────────
# Group all issues by who created them (the "assigner").
# If --assigned-by is given, filter to that person only.
# If not given and all issues come from one person, use them automatically.
# If multiple people, print groups and ask.
DETECTION=$(echo "$ISSUES_JSON" | python3 -c "
import sys, json, os

data = json.load(sys.stdin)
forced = os.environ.get('ASSIGNED_BY_ARG', '').lower()

# Exclude PRs
issues = [i for i in data if 'pull_request' not in i]

# Group by creator login
from collections import defaultdict
groups = defaultdict(list)
for issue in issues:
    creator = issue.get('user', {}).get('login', 'unknown')
    groups[creator].append({
        'number': issue['number'],
        'title':  issue['title'],
        'url':    issue['html_url'],
        'body':   issue.get('body') or ''
    })

if forced:
    # Filter to the forced assigner
    matched = groups.get(forced, [])
    if not matched:
        # try case-insensitive
        for k, v in groups.items():
            if k.lower() == forced:
                matched = v
                break
    result = {
        'mode': 'single',
        'assigner': forced,
        'issues': matched
    }
else:
    assigners = list(groups.keys())
    if len(assigners) == 0:
        result = {'mode': 'empty', 'assigner': '', 'issues': [], 'groups': {}}
    elif len(assigners) == 1:
        result = {
            'mode': 'single',
            'assigner': assigners[0],
            'issues': groups[assigners[0]]
        }
    else:
        result = {
            'mode': 'multi',
            'assigner': '',
            'issues': [],
            'groups': {k: v for k, v in groups.items()}
        }

print(json.dumps(result))
" ASSIGNED_BY_ARG="$ASSIGNED_BY")

DETECT_MODE=$(echo "$DETECTION" | python3 -c "import sys,json; print(json.load(sys.stdin)['mode'])")

# ── Handle: no issues at all ──────────────────────────────────────────────────
if [[ "$DETECT_MODE" == "empty" ]]; then
  warn "No open issues found assigned to ${MY_USERNAME} in ${REPO}."
  exit 0
fi

# ── Handle: multiple assigners → ask which group ──────────────────────────────
if [[ "$DETECT_MODE" == "multi" ]]; then
  echo ""
  echo -e "${BOLD}Issues assigned to you come from multiple people:${RESET}"
  echo ""
  GROUPS_LIST=$(echo "$DETECTION" | python3 -c "
import sys, json
d = json.load(sys.stdin)
groups = d['groups']
for i, (assigner, issues) in enumerate(groups.items(), 1):
    nums = ', '.join('#' + str(x['number']) for x in issues)
    print(f'  [{i}] {assigner}  ({len(issues)} issue(s): {nums})')
print()
print('  [*] Fix all groups (separate PRs per assigner)')
")
  echo "$GROUPS_LIST"

  echo -ne "${BOLD}Choose a group number (or * for all): ${RESET}"
  read -r CHOICE

  if [[ "$CHOICE" == "*" ]]; then
    # Re-run once per assigner — delegate to sub-invocations
    echo "$DETECTION" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for assigner in d['groups'].keys():
    print(assigner)
" | while read -r assigner; do
      log "Launching Solvix for issues from ${assigner}..."
      bash "$0" --repo "$REPO" --assigned-by "$assigner" ${TEST_CMD:+--test-cmd "$TEST_CMD"}
    done
    exit 0
  else
    SELECTED_ASSIGNER=$(echo "$DETECTION" | python3 -c "
import sys, json
d = json.load(sys.stdin)
groups = d['groups']
keys = list(groups.keys())
idx = int('$CHOICE') - 1
print(keys[idx])
")
    ISSUE_DATA=$(echo "$DETECTION" | python3 -c "
import sys, json
d = json.load(sys.stdin)
groups = d['groups']
keys = list(groups.keys())
idx = int('$CHOICE') - 1
import json as j
print(j.dumps(groups[keys[idx]]))
")
    ASSIGNED_BY="$SELECTED_ASSIGNER"
  fi
else
  # Single assigner (auto-detected or forced)
  ASSIGNED_BY=$(echo "$DETECTION" | python3 -c "import sys,json; print(json.load(sys.stdin)['assigner'])")
  ISSUE_DATA=$(echo "$DETECTION" | python3 -c "import sys,json; import json as j; print(j.dumps(json.load(sys.stdin)['issues']))")
fi

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
  exit 0
fi

ok "Found ${COUNT} issue(s) assigned by ${BOLD}${ASSIGNED_BY}${RESET}:"
echo ""
echo "$ISSUE_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i, issue in enumerate(data, 1):
    print(f'  [{i}] #{issue[\"number\"]} — {issue[\"title\"]}')
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
echo -e "  Assigned by  : ${CYAN}${ASSIGNED_BY}${RESET} (auto-detected)"
echo -e "  PR strategy  : ${CYAN}ONE PR closing all ${COUNT} issues${RESET}"
echo -e "  Test command : ${CYAN}${AGENT_TEST_CMD}${RESET}"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── Launch Bob (foreground — live logs stream to this terminal) ───────────────
# shellcheck source=scripts/bob_launch.sh
source "$(dirname "${BASH_SOURCE[0]}")/bob_launch.sh"

BOB_MESSAGE="REPO=${REPO}
ISSUE_NUMBERS=${NUMBERS}
BRANCH=${BRANCH}
FORK_OWNER=${MY_USERNAME}
TEST_CMD=${AGENT_TEST_CMD}
ASSIGNED_BY=${ASSIGNED_BY}

Please read agent/multi_orchestrator.md and execute the full multi-issue workflow with these variables."

ok "Starting workflow — Bob output will stream below."
echo -e "  Issues : ${CYAN}$(echo $NUMBERS | sed 's/ /, #/g' | sed 's/^/#/')${RESET}"
echo -e "  Branch : ${CYAN}${BRANCH}${RESET}"
echo ""

if ! bob_run "$(pwd)/agent/multi_orchestrator.md" "$BOB_MESSAGE"; then
  echo ""
  warn "Bob was not found automatically."
  echo ""
  echo "  Set the path manually and re-run:"
  echo "    export BOB_APP_PATH=\"/path/to/IBM Bob.app\""
  echo ""
  echo "  Or paste these variables into Bob manually:"
  echo ""
  echo "       REPO=$REPO"
  echo "       ISSUE_NUMBERS=$NUMBERS"
  echo "       BRANCH=$BRANCH"
  echo "       FORK_OWNER=$MY_USERNAME"
  echo "       TEST_CMD=${AGENT_TEST_CMD}"
  echo "       ASSIGNED_BY=$ASSIGNED_BY"
  echo ""
  echo "  Then open agent/multi_orchestrator.md in Bob → Agent mode."
  exit 1
fi
