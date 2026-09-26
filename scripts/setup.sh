#!/usr/bin/env bash
# =============================================================================
# Solvix — Environment Setup Validator
# =============================================================================
# Run once before your first use:
#   ./solvix setup
# =============================================================================

set -uo pipefail

PASS=0; FAIL=0; WARN=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✓${RESET}  $*";  PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${RESET}  $*";    FAIL=$((FAIL+1)); }
warn() { echo -e "  ${YELLOW}~${RESET}  $*"; WARN=$((WARN+1)); }
info() { echo -e "  ${CYAN}i${RESET}  $*"; }

# Auto-load .env if present
SOLVIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "${SOLVIX_DIR}/.env" ]] && { set -a; source "${SOLVIX_DIR}/.env"; set +a; }

# Load saved environment mode
SOLVIX_MODE="${SOLVIX_MODE:-}"
[[ -z "$SOLVIX_MODE" && -f "${SOLVIX_DIR}/.solvix_env" ]] && source "${SOLVIX_DIR}/.solvix_env"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║              Solvix — Setup Check                     ║${RESET}"
if [[ "$SOLVIX_MODE" == "cli" ]]; then
  echo -e "${BOLD}║              Environment: Bob Shell CLI  (live logs)  ║${RESET}"
elif [[ "$SOLVIX_MODE" == "ide" ]]; then
  echo -e "${BOLD}║              Environment: Bob IDE  (logs in IDE chat) ║${RESET}"
else
  echo -e "${BOLD}║              Run ./solvix env to configure first      ║${RESET}"
fi
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── 1. System tools ───────────────────────────────────────────────────────────
echo -e "${CYAN}System tools:${RESET}"
command -v git     &>/dev/null && ok "git"     || fail "git is not installed"
command -v curl    &>/dev/null && ok "curl"    || fail "curl is not installed"
command -v python3 &>/dev/null && ok "python3" || fail "python3 is not installed"
if [[ "$SOLVIX_MODE" != "ide" ]]; then
  command -v node &>/dev/null && ok "node ($(node --version 2>/dev/null))" || \
    warn "node not found — needed to install Bob Shell CLI via npm"
fi

# ── 2. Bob Shell CLI (required for CLI mode, skipped for IDE mode) ────────────
if [[ "$SOLVIX_MODE" != "ide" ]]; then
  echo ""
  echo -e "${CYAN}Bob Shell CLI (bob):${RESET}"
  BOB_SHELL_PATH=""
  if command -v bob &>/dev/null; then
    BOB_SHELL_PATH="$(command -v bob)"
  else
    for candidate in \
      "${HOME}/.nvm/versions/node/*/bin/bob" \
      "/usr/local/bin/bob" \
      "/opt/homebrew/bin/bob" \
      "${HOME}/.local/bin/bob" \
      "${HOME}/bin/bob" \
      "${HOME}/.npm-global/bin/bob"; do
      for expanded in $candidate; do
        if [[ -x "$expanded" ]]; then
          BOB_SHELL_PATH="$expanded"
          break 2
        fi
      done
    done
  fi

  if [[ -n "$BOB_SHELL_PATH" ]]; then
    BOB_VERSION=$("$BOB_SHELL_PATH" --version 2>/dev/null | head -1) || BOB_VERSION="unknown"
    ok "Bob Shell CLI found: ${BOB_SHELL_PATH} (${BOB_VERSION})"
    info "Live logs will stream to this terminal during agent runs."
  else
    [[ "$SOLVIX_MODE" == "cli" ]] && \
      fail "Bob Shell CLI not installed — required for CLI mode" || \
      warn "Bob Shell CLI not installed (will use Bob IDE fallback)"
    echo ""
    echo -e "    Install with: ${BOLD}npm install -g @ibm/bob${RESET}"
    echo -e "    or visit:     ${CYAN}https://bob.ibm.com${RESET}"
  fi
fi

# ── 3. BOB_API_KEY (CLI mode only — not needed for IDE) ───────────────────────
if [[ "$SOLVIX_MODE" == "ide" ]]; then
  echo ""
  echo -e "${CYAN}Bob API key:${RESET}"
  info "Not required for Bob IDE mode — Bob IDE uses its own login session."
elif [[ "$SOLVIX_MODE" == "cli" ]] || [[ -z "$SOLVIX_MODE" ]]; then
  echo ""
  echo -e "${CYAN}Bob API key (BOB_API_KEY):${RESET}"
  if [[ -n "${BOB_API_KEY:-}" ]]; then
    if [[ ${#BOB_API_KEY} -ge 20 ]]; then
      ok "BOB_API_KEY is set (${#BOB_API_KEY} chars)"
    else
      fail "BOB_API_KEY looks too short — may be invalid"
      echo -e "    Get a valid key from: ${CYAN}https://bob.ibm.com/admin/apikeys${RESET}"
    fi
  else
    fail "BOB_API_KEY is NOT set"
    echo ""
    echo -e "    ${RED}Required for Bob Shell CLI to authenticate.${RESET}"
    echo -e "    1. Go to:  ${CYAN}https://bob.ibm.com/admin/apikeys${RESET}"
    echo -e "    2. Create an API key and add it to your .env:"
    echo -e "       ${BOLD}export BOB_API_KEY=your_key_here${RESET}"
  fi
fi

# ── 4. GitHub PAT ─────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}GitHub Personal Access Token (GITHUB_PERSONAL_ACCESS_TOKEN):${RESET}"

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
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('login','?'))" 2>/dev/null) || GH_USER="?"
    ok "GitHub PAT valid — authenticated as: ${BOLD}${GH_USER}${RESET}"

    SCOPES=$(curl -sI \
      -H "Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/user 2>/dev/null \
      | grep -i "x-oauth-scopes:" | tr -d '\r' | sed 's/x-oauth-scopes: //I') || SCOPES=""

    if echo "$SCOPES" | grep -q "repo"; then
      ok "PAT has 'repo' scope (required for fork/PR)"
    else
      fail "PAT is missing 'repo' scope"
      echo -e "    Regenerate your PAT at: ${CYAN}https://github.com/settings/tokens${RESET}"
      echo -e "    Required scopes: ${BOLD}repo${RESET}, ${BOLD}workflow${RESET}"
    fi
  elif [[ "$HTTP_STATUS" == "401" ]]; then
    fail "GitHub PAT is invalid or expired (HTTP 401)"
    echo -e "    Regenerate at: ${CYAN}https://github.com/settings/tokens${RESET}"
  else
    fail "GitHub PAT check failed (HTTP ${HTTP_STATUS})"
  fi
else
  fail "GITHUB_PERSONAL_ACCESS_TOKEN is NOT set"
  echo ""
  echo -e "    ${RED}This is required for Solvix to access GitHub.${RESET}"
  echo -e "    1. Create a token: ${CYAN}https://github.com/settings/tokens${RESET}"
  echo -e "    2. Required scopes: ${BOLD}repo${RESET}, ${BOLD}workflow${RESET}"
  echo -e "    3. Add to your .env file:"
  echo -e "       ${BOLD}echo 'export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...' >> .env${RESET}"
fi

# ── 5. .env file ──────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}.env file ($(pwd)/.env):${RESET}"
if [[ -f "$(pwd)/.env" ]]; then
  ok ".env file exists — credentials loaded automatically on each run"
else
  warn ".env file not found"
  echo -e "    Create one to avoid exporting variables every session:"
  echo -e "    ${BOLD}cat > .env << 'EOF'"
  echo -e "    export BOB_API_KEY=your_bob_api_key"
  echo -e "    export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token"
  echo -e "    EOF${RESET}"
fi

# ── 6. Bob IDE (optional, for fallback) ───────────────────────────────────────
echo ""
echo -e "${CYAN}Bob IDE (optional fallback):${RESET}"
BOB_IDE_FOUND=false
for base in "${HOME}/Applications" "/Applications"; do
  if [[ -x "${base}/IBM Bob.app/Contents/MacOS/IBM Bob" ]]; then
    ok "Bob IDE found: ${base}/IBM Bob.app"
    BOB_IDE_FOUND=true
    break
  fi
done
IDE_SPOTLIGHT=$(mdfind "kMDItemFSName == 'IBM Bob.app'" 2>/dev/null | head -1)
if [[ "$BOB_IDE_FOUND" == "false" && -n "$IDE_SPOTLIGHT" ]]; then
  ok "Bob IDE found via Spotlight: ${IDE_SPOTLIGHT}"
  BOB_IDE_FOUND=true
fi
if [[ "$BOB_IDE_FOUND" == "false" ]]; then
  warn "Bob IDE not found (optional — used as fallback when Bob Shell CLI is absent)"
fi

# ── 7. Optional: Docker ───────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Docker (optional — for containerised test runs):${RESET}"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  ok "Docker is running"
else
  warn "Docker not running (optional — only needed if target repo uses Docker for tests)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
TOTAL=$((PASS+FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  All checks passed ($PASS/$TOTAL). Solvix is ready.${RESET}"
  echo ""
  echo -e "  Run:  ${CYAN}./solvix --repo owner/repo-name${RESET}"
else
  echo -e "${RED}${BOLD}  $FAIL check(s) failed — fix the issues above before running.${RESET}"
  echo ""
  if ! command -v bob &>/dev/null && [[ -z "${BOB_SHELL_PATH}" ]]; then
    echo -e "  ${YELLOW}Most important:${RESET} install Bob Shell CLI first:"
    echo -e "    ${BOLD}npm install -g @ibm/bob${RESET}"
    echo ""
  fi
  if [[ -z "${BOB_API_KEY:-}" ]]; then
    echo -e "  ${YELLOW}Then:${RESET} get your Bob API key from ${CYAN}https://bob.ibm.com/admin/apikeys${RESET}"
    echo ""
  fi
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
