#!/usr/bin/env bash
# =============================================================================
# Solvix — Entry Point
# =============================================================================
# Usage:
#   ./scripts/run_agent.sh --repo owner/repo-name --issue 42
#
# Optional:
#   --fork-owner   your-github-username  (default: derived from PAT)
#   --test-cmd     "pytest"              (default: auto-detected)
#   --branch       fix/issue-42          (default: fix/issue-<N>)
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[agent]${RESET} $*"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
die()  { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
REPO=""
ISSUE_NUMBER=""
FORK_OWNER=""
TEST_CMD=""
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO="$2";         shift 2 ;;
    --issue)       ISSUE_NUMBER="$2"; shift 2 ;;
    --fork-owner)  FORK_OWNER="$2";   shift 2 ;;
    --test-cmd)    TEST_CMD="$2";     shift 2 ;;
    --branch)      BRANCH="$2";       shift 2 ;;
    *)             die "Unknown argument: $1" ;;
  esac
done

[[ -z "$REPO" ]]         && die "--repo is required (e.g. --repo owner/repo-name)"
[[ -z "$ISSUE_NUMBER" ]] && die "--issue is required (e.g. --issue 42)"

# ── Derived values ────────────────────────────────────────────────────────────
REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"
BRANCH="${BRANCH:-fix/issue-${ISSUE_NUMBER}}"

# ── Environment validation ────────────────────────────────────────────────────
log "Validating environment..."

[[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] && \
  die "GITHUB_PERSONAL_ACCESS_TOKEN is not set.\n  export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_..."

# Resolve fork owner from PAT if not supplied
if [[ -z "$FORK_OWNER" ]]; then
  log "Resolving GitHub username from PAT..."
  FORK_OWNER=$(curl -sf \
    -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])" 2>/dev/null) \
    || die "Could not resolve GitHub username. Check your PAT."
  ok "Fork owner: ${FORK_OWNER}"
fi

# Auto-detect test command if not supplied
if [[ -z "$TEST_CMD" ]]; then
  warn "--test-cmd not supplied. It will be auto-detected by the agent."
  TEST_CMD="AUTO"
fi

ok "Environment validated."

# ── Print run configuration ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Solvix — Autonomous Contributor Agent        ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "  Repo         : ${CYAN}${REPO}${RESET}"
echo -e "  Issue        : ${CYAN}#${ISSUE_NUMBER}${RESET}"
echo -e "  Fork owner   : ${CYAN}${FORK_OWNER}${RESET}"
echo -e "  Branch       : ${CYAN}${BRANCH}${RESET}"
echo -e "  Test command : ${CYAN}${TEST_CMD}${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── Export variables for Bob ──────────────────────────────────────────────────
export AGENT_REPO="$REPO"
export AGENT_REPO_OWNER="$REPO_OWNER"
export AGENT_REPO_NAME="$REPO_NAME"
export AGENT_ISSUE_NUMBER="$ISSUE_NUMBER"
export AGENT_FORK_OWNER="$FORK_OWNER"
export AGENT_BRANCH="$BRANCH"
export AGENT_TEST_CMD="$TEST_CMD"

# ── Instructions ──────────────────────────────────────────────────────────────
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo "  1. Open IBM Bob 2.0 in this directory."
echo "  2. Activate the skill:  type  'use skill solvix'"
echo "  3. Open agent/orchestrator.md in Bob → Agent mode."
echo "  4. Provide the following when prompted:"
echo ""
echo "       REPO=$REPO"
echo "       ISSUE_NUMBER=$ISSUE_NUMBER"
echo "       FORK_OWNER=$FORK_OWNER"
echo "       TEST_CMD=$TEST_CMD"
echo "       BRANCH=$BRANCH"
echo ""
echo "  5. Approve subagent spawns as they appear (Step 3 and Step 5 each"
echo "     spawn 2 parallel subagents)."
echo ""
echo "  The agent will log each step with [STEP N ✓] as it completes."
echo "  When done, it will print the PR URL."
echo ""
log "Ready. Start Bob and follow the instructions above."
