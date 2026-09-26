#!/usr/bin/env bash
# =============================================================================
# Solvix — Bob Launch Helper
# =============================================================================
# Source this file, then call:
#
#   bob_run <orchestrator_file> <message>
#
# Launch strategy (in priority order):
#
#   1. Bob Shell CLI  (`bob run`)  — headless, streams all output to terminal
#   2. Bob IDE CLI    (bobide chat) — opens/injects into GUI, no terminal output
#   3. Fail with actionable message
#
# bob_run runs in the FOREGROUND and only returns when the agent is done.
# =============================================================================

# ── Auto-load .env if present (picks up BOB_API_KEY, GITHUB_PAT, etc.) ────────
_solvix_load_env() {
  local env_file
  for env_file in \
    "$(dirname "${BASH_SOURCE[0]}")/../.env" \
    "$(pwd)/.env"; do
    if [[ -f "$env_file" ]]; then
      # shellcheck disable=SC1090
      set -a; source "$env_file"; set +a
      break
    fi
  done
}
_solvix_load_env

# ── Find Bob Shell CLI (`bob run`) ────────────────────────────────────────────
_bob_shell_find() {
  BOB_SHELL=""

  # 1. Explicit override
  if [[ -n "${BOB_CLI_PATH:-}" ]] && [[ -x "$BOB_CLI_PATH" ]]; then
    BOB_SHELL="$BOB_CLI_PATH"
    return 0
  fi

  # 2. Already in PATH
  if command -v bob &>/dev/null; then
    BOB_SHELL="$(command -v bob)"
    return 0
  fi

  # 3. Common install locations (nvm, homebrew, local)
  local candidates=(
    "${HOME}/.nvm/versions/node/*/bin/bob"
    "${HOME}/.nvm/versions/node/*/bin/bob"
    "/usr/local/bin/bob"
    "/opt/homebrew/bin/bob"
    "${HOME}/.local/bin/bob"
    "${HOME}/bin/bob"
    "${HOME}/.npm-global/bin/bob"
    "/usr/bin/bob"
  )
  local c
  for c in "${candidates[@]}"; do
    # expand glob
    for expanded in $c; do
      if [[ -x "$expanded" ]]; then
        BOB_SHELL="$expanded"
        return 0
      fi
    done
  done

  return 1
}

# ── Find Bob IDE app (bobide chat — GUI injection, no terminal output) ─────────
_bob_ide_find() {
  BOB_IDE_CLI=""
  BOB_IDE_JS=""

  local search_dirs=(
    "${HOME}/Applications"
    "/Applications"
    "${HOME}/Desktop"
    "/opt/homebrew/Applications"
    "/usr/local/Applications"
  )
  local app_names=("IBM Bob.app" "Bob.app")

  local dir app candidate exe js
  for dir in "${search_dirs[@]}"; do
    for app in "${app_names[@]}"; do
      candidate="${dir}/${app}"
      exe="${candidate}/Contents/MacOS/IBM Bob"
      js="${candidate}/Contents/Resources/app/out/cli.js"
      if [[ ! -x "$exe" ]]; then
        exe=$(find "${candidate}/Contents/MacOS" -maxdepth 1 -type f -perm +111 2>/dev/null | head -1)
      fi
      if [[ -n "$exe" && -x "$exe" && -f "$js" ]]; then
        BOB_IDE_CLI="$exe"; BOB_IDE_JS="$js"
        return 0
      fi
    done
  done

  # Spotlight fallback
  local spotlight
  spotlight=$(mdfind "kMDItemFSName == 'IBM Bob.app' || kMDItemFSName == 'Bob.app'" 2>/dev/null | head -1)
  if [[ -n "$spotlight" ]]; then
    exe="${spotlight}/Contents/MacOS/IBM Bob"
    js="${spotlight}/Contents/Resources/app/out/cli.js"
    if [[ ! -x "$exe" ]]; then
      exe=$(find "${spotlight}/Contents/MacOS" -maxdepth 1 -type f -perm +111 2>/dev/null | head -1)
    fi
    if [[ -n "$exe" && -x "$exe" && -f "$js" ]]; then
      BOB_IDE_CLI="$exe"; BOB_IDE_JS="$js"
      return 0
    fi
  fi

  return 1
}

# ── Main entry point ──────────────────────────────────────────────────────────
# Usage: bob_run <orchestrator_file> <message>
#
# Respects SOLVIX_MODE=cli|ide (set by the solvix entry-point).
# Falls back to auto-detection if SOLVIX_MODE is unset.
bob_run() {
  local orchestrator_file="$1"
  local message="$2"
  local workspace
  workspace="$(pwd)"

  local mode="${SOLVIX_MODE:-auto}"

  # ── CLI mode: Bob Shell CLI — streams every step to this terminal ─────────────
  if [[ "$mode" == "cli" ]] || [[ "$mode" == "auto" ]]; then
    if _bob_shell_find; then
      log "Bob Shell CLI: ${BOB_SHELL}"
      log "Running in headless mode — all steps stream below:"
      echo ""
      echo -e "${BOLD}──────────────────────── Bob output ────────────────────────${RESET}"
      echo ""

      "$BOB_SHELL" run \
        --mode agent \
        --workspace "$workspace" \
        --trust \
        "$message"

      local exit_code=$?
      echo ""
      echo -e "${BOLD}────────────────────────────────────────────────────────────${RESET}"
      echo ""
      return $exit_code
    fi

    # CLI mode was requested but bob not found
    if [[ "$mode" == "cli" ]]; then
      echo ""
      echo -e "${RED}[✗]${RESET} Bob Shell CLI not found."
      echo ""
      echo -e "  Install it: ${BOLD}npm install -g @ibm/bob${RESET}"
      echo -e "  Then add ${BOLD}BOB_API_KEY${RESET} to your .env (from https://bob.ibm.com/admin/apikeys)"
      echo -e "  Then re-run: ${CYAN}./solvix --repo ${REPO:-owner/repo}${RESET}"
      echo ""
      echo -e "  Or switch to IDE mode: ${BOLD}./solvix env${RESET}"
      return 1
    fi
  fi

  # ── IDE mode: Bob IDE — opens a new chat, logs appear in IDE ─────────────────
  if [[ "$mode" == "ide" ]] || [[ "$mode" == "auto" ]]; then
    if _bob_ide_find; then
      log "Bob IDE: ${BOB_IDE_CLI%/Contents/*}"
      log "Opening new chat in Bob IDE..."
      echo ""
      echo -e "  ${BOLD}${YELLOW}👉  Switch to Bob IDE now — the workflow is starting in a new chat.${RESET}"
      echo -e "     Watch the chat panel for live step-by-step progress."
      echo -e "     You'll see [STEP N ✓] as each step completes."
      echo ""

      "$BOB_IDE_CLI" "$BOB_IDE_JS" chat \
        --mode agent \
        --new-window \
        --add-file "$orchestrator_file" \
        "$message" &
      local ide_pid=$!

      sleep 2
      if kill -0 "$ide_pid" 2>/dev/null; then
        wait "$ide_pid" 2>/dev/null || true
      fi

      ok "Workflow sent to Bob IDE."
      echo -e "  ${YELLOW}Monitor progress in Bob IDE → Chat panel.${RESET}"
      echo -e "  When done, the PR URL will appear there."
      echo ""
      return 0
    fi

    # IDE mode was requested but app not found
    if [[ "$mode" == "ide" ]]; then
      echo ""
      echo -e "${RED}[✗]${RESET} Bob IDE not found."
      echo ""
      echo -e "  Install it from: ${CYAN}https://bob.ibm.com${RESET}"
      echo -e "  Or switch to CLI mode: ${BOLD}./solvix env${RESET}"
      return 1
    fi
  fi

  # ── Neither found (auto mode exhausted both) ──────────────────────────────────
  echo ""
  echo -e "${RED}[✗]${RESET} Bob not found. Run ${BOLD}./solvix env${RESET} to configure your environment."
  echo ""
  echo -e "  ${BOLD}Option 1 — Bob Shell CLI (live terminal logs):${RESET}"
  echo -e "    npm install -g @ibm/bob"
  echo ""
  echo -e "  ${BOLD}Option 2 — Bob IDE (logs in IDE chat):${RESET}"
  echo -e "    https://bob.ibm.com"
  echo ""
  return 1
}
