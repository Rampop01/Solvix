#!/usr/bin/env bash
# =============================================================================
# Solvix — Auto-Approve Setup
# =============================================================================
# Patches ~/.bob/mcp.json to add alwaysAllow for every GitHub MCP tool
# that Solvix uses, so Bob never prompts for approval mid-run.
#
# Run once:
#   ./scripts/setup_approvals.sh
#
# Safe to re-run — it is idempotent.
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
die()  { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }
log()  { echo -e "${CYAN}[solvix]${RESET} $*"; }

# ── All GitHub MCP tools used by Solvix ──────────────────────────────────────
# Covers: issue reading, repo tree, code search, fork, branch, file push, PR
SOLVIX_TOOLS=(
  "get_issue"
  "list_issues"
  "get_issue_comments"
  "search_code"
  "get_repository_tree"
  "get_file_contents"
  "fork_repository"
  "create_branch"
  "push_files"
  "create_pull_request"
  "list_pull_requests"
  "get_pull_request"
  "create_or_update_file"
  "get_repository"
  "list_repository_contents"
  "search_repositories"
)

MCP_CONFIG="${HOME}/.bob/mcp.json"

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Solvix — Auto-Approve Setup                          ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── Locate the config ────────────────────────────────────────────────────────
if [[ ! -f "$MCP_CONFIG" ]]; then
  warn "~/.bob/mcp.json not found."
  echo ""
  echo "  This means either:"
  echo "  · IBM Bob is not installed yet, or"
  echo "  · It uses a different config path."
  echo ""
  echo "  To set up manually, add this to your GitHub MCP server entry in"
  echo "  Bob Settings → MCP Servers:"
  echo ""
  echo '    "alwaysAllow": ['
  for tool in "${SOLVIX_TOOLS[@]}"; do
    echo "      \"${tool}\","
  done
  echo '    ]'
  echo ""
  exit 0
fi

log "Found MCP config at: ${MCP_CONFIG}"
log "Backing up to: ${MCP_CONFIG}.bak"
cp "$MCP_CONFIG" "${MCP_CONFIG}.bak"
ok "Backup created."

# ── Patch the config with Python ─────────────────────────────────────────────
log "Patching alwaysAllow for all Solvix tools..."

TOOLS_JSON=$(printf '"%s",' "${SOLVIX_TOOLS[@]}")
TOOLS_JSON="[${TOOLS_JSON%,}]"

python3 - "$MCP_CONFIG" "$TOOLS_JSON" <<'PYEOF'
import sys, json, re

config_path = sys.argv[1]
new_tools = json.loads(sys.argv[2])

with open(config_path, 'r') as f:
    config = json.load(f)

# Find the GitHub MCP server entry (looks for github in name, url, or command)
mcpServers = config.get('mcpServers', {})

patched = False
for name, server in mcpServers.items():
    is_github = (
        'github' in name.lower() or
        'github.com' in str(server.get('url', '')).lower() or
        'github-mcp-server' in str(server.get('command', '')).lower() or
        'githubcopilot' in str(server.get('url', '')).lower()
    )
    if is_github:
        existing = server.get('alwaysAllow', [])
        merged = list(dict.fromkeys(existing + new_tools))  # deduplicate, preserve order
        server['alwaysAllow'] = merged
        patched = True
        print(f"  Patched server: {name} ({len(merged)} tools in alwaysAllow)")

if not patched:
    print("  WARNING: No GitHub MCP server found in config. Nothing patched.")
    print("  Add alwaysAllow manually to your GitHub MCP server entry.")
    sys.exit(0)

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print("  Config saved.")
PYEOF

echo ""
ok "Done. Bob will no longer prompt for approval on these tools:"
echo ""
for tool in "${SOLVIX_TOOLS[@]}"; do
  echo -e "  ${GREEN}·${RESET}  ${tool}"
done
echo ""

echo -e "${BOLD}Note:${RESET} Subagent spawning approval is controlled by Bob's UI settings."
echo "  In Bob → Settings → Permissions, enable:"
echo "  · 'Auto-approve subagent spawning'"
echo "  or run Bob with --auto-approve-subagents if using the CLI."
echo ""
echo -e "${BOLD}Restart Bob for the changes to take effect.${RESET}"
echo ""
