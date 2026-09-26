#!/usr/bin/env bash
# =============================================================================
# Solvix — Environment Setup Validator
# =============================================================================
# Run this once before your first demo pass to confirm everything is in place.
# =============================================================================

set -uo pipefail

PASS=0; FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

check() {
  local label="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET}  $label"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}✗${RESET}  $label"
    FAIL=$((FAIL+1))
  fi
}

check_env() {
  local var="$1"; local label="$2"
  if [[ -n "${!var:-}" ]]; then
    echo -e "  ${GREEN}✓${RESET}  $label (set)"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}✗${RESET}  $label (${var} is NOT set)"
    FAIL=$((FAIL+1))
  fi
}

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Solvix — Setup Check                                  ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── System tools ──────────────────────────────────────────────────────────────
echo -e "${CYAN}System tools:${RESET}"
check "git"           command -v git
check "curl"          command -v curl
check "python3"       command -v python3

# ── Optional: Docker (for containerised test runs) ────────────────────────────
echo ""
echo -e "${CYAN}Optional tools:${RESET}"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${RESET}  Docker (running)"
  ((PASS++))
else
  echo -e "  ${YELLOW}~${RESET}  Docker not running (optional — needed only for containerised tests)"
fi

# ── Environment variables ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Environment variables:${RESET}"
check_env "GITHUB_PERSONAL_ACCESS_TOKEN" "GITHUB_PERSONAL_ACCESS_TOKEN"

# ── GitHub PAT validation (scope check) ──────────────────────────────────────
echo ""
echo -e "${CYAN}GitHub PAT validation:${RESET}"
if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
  HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user 2>/dev/null) || HTTP_STATUS="000"

  if [[ "$HTTP_STATUS" == "200" ]]; then
    GH_USER=$(curl -sf \
      -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/user 2>/dev/null \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('login','?'))" 2>/dev/null) || GH_USER="?"
    echo -e "  ${GREEN}✓${RESET}  GitHub PAT valid — authenticated as: ${BOLD}${GH_USER}${RESET}"
    ((PASS++))

    # Check for repo scope
    SCOPES=$(curl -sI \
      -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/user 2>/dev/null \
      | grep -i "x-oauth-scopes:" | tr -d '\r' | sed 's/x-oauth-scopes: //I') || SCOPES=""
    if echo "$SCOPES" | grep -q "repo"; then
      echo -e "  ${GREEN}✓${RESET}  PAT has 'repo' scope (required for fork/PR)"
      ((PASS++))
    else
      echo -e "  ${RED}✗${RESET}  PAT is missing 'repo' scope — regenerate with: repo, workflow"
      ((FAIL++))
    fi
  else
    echo -e "  ${RED}✗${RESET}  GitHub PAT invalid (HTTP ${HTTP_STATUS})"
    ((FAIL++))
  fi
else
  echo -e "  ${YELLOW}~${RESET}  Skipped — GITHUB_PERSONAL_ACCESS_TOKEN not set"
fi

# ── IBM Bob MCP reminder ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}IBM Bob configuration (manual checks):${RESET}"
echo -e "  ${YELLOW}?${RESET}  GitHub MCP server configured in Bob Settings → MCP Servers"
echo -e "  ${YELLOW}?${RESET}  Toolsets enabled: repos, issues, pull_requests, git"
echo -e "  ${YELLOW}?${RESET}  Agent mode enabled"
echo -e "  ${YELLOW}?${RESET}  Subagent spawning available (approve during demo or auto-approve)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  All automated checks passed ($PASS/$PASS).${RESET}"
  echo -e "  Verify the Bob configuration items above, then you're ready."
else
  echo -e "${RED}${BOLD}  $FAIL check(s) failed. Fix the issues above before running the agent.${RESET}"
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
