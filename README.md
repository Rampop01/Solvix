# Solvix
### IBM Bob 2.0 Hackathon — Solvix

An agentic workflow built on **IBM Bob 2.0** that automates the full contributor-side
lifecycle: **issue assigned → fork → clone → understand → locate → fix → verify → PR**.

---

## Before / After

| Step | Manual (before) | Agent (after) |
|------|----------------|---------------|
| Fork repo | Manual GitHub click | `fork_repository` MCP tool |
| Clone locally | `git clone ...` in terminal | Automated via shell subagent |
| Read issue + context | Open browser, read threads | `issue_read` + `get_comments` |
| Find relevant files | Grep, blame, intuition | 2 parallel subagents (keyword + traceback) |
| Write fix | Open editor, code | Bob agent mode with full context |
| Run test suite | `npm test` / `pytest` manually | Automated subagent |
| Write missing test | Manual | Automated subagent if coverage missing |
| Commit + push | `git add/commit/push` | Automated via MCP + shell |
| Open PR with right description | Manual, easy to forget `Closes #N` | `create_pull_request` with template |
| **Total manual steps** | **~15–20** | **1 (trigger)** |

---

## Prerequisites

### Choose your environment

Solvix works with two Bob environments. Pick one — you'll be asked on first run.

| | Bob Shell CLI | Bob IDE |
|---|---|---|
| **How it works** | Runs Bob headlessly from the terminal | Opens a chat in the Bob desktop app |
| **Where you see logs** | Right here in this terminal | In the Bob IDE chat panel |
| **Bob API key needed** | ✅ Yes | ❌ No |
| **Install** | `npm install -g @ibm/bob` | https://bob.ibm.com |

---

### Required for both environments

**GitHub Personal Access Token**
1. Go to: **https://github.com/settings/tokens**
2. Create a token with scopes: `repo`, `workflow`

**GitHub MCP Server** (configured in Bob IDE → Settings → MCP Servers → Add):
```json
{
  "type": "remote",
  "url": "https://api.githubcopilot.com/mcp/",
  "headers": { "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" }
}
```
Required toolsets: `repos`, `issues`, `pull_requests`, `git`

---

### Required for Bob Shell CLI only

**Bob API Key**
1. Go to: **https://bob.ibm.com/admin/apikeys**
2. Create an API key

---

### .env file — store all credentials here

Create `.env` in the Solvix directory (loaded automatically on every run):

```bash
# For Bob Shell CLI users:
cat > .env << 'EOF'
export BOB_API_KEY=your_bob_api_key
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
EOF

# For Bob IDE users (no BOB_API_KEY needed):
cat > .env << 'EOF'
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
EOF
```

---

## Quick Start

```bash
# 1. Create your .env file
cat > .env << 'EOF'
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
export BOB_API_KEY=your_bob_api_key   # only needed for Bob Shell CLI
EOF

# 2. First run — Solvix asks which environment you're using (saved for future runs)
./solvix --repo owner/repo-name

# Or: validate everything first
./solvix setup

# 3. Fix a single specific issue
./solvix --repo owner/repo-name --issue 42

# Change your environment choice at any time
./solvix env
```

On first run, you'll see:

```
How are you running Bob?

  [1] Bob Shell CLI  (terminal — live logs stream here)
  [2] Bob IDE        (desktop app — logs appear in the IDE chat)

Enter 1 or 2:
```

Your choice is saved. Every subsequent run goes straight to work — no prompts.

---

## What You'll See

**Bob Shell CLI mode** — everything streams to the terminal:

```
╔═══════════════════════════════════════════════════════╗
║            Solvix — Autonomous Issue Fixer            ║
║            Mode: Bob Shell CLI  (live logs)           ║
╚═══════════════════════════════════════════════════════╝

[✓] Found 3 issue(s) assigned by Wilfred007
──────────────────────── Bob output ────────────────────────

[STEP 1 ✓] Issue #42 understood: Fix null pointer in checkout
[STEP 2 ✓] Forked + cloned. Branch: fix/issues-42-43-44
[STEP 3 ✓] Code located: src/checkout.ts:142
[STEP 4 ✓] Fix applied (3 files changed)
[STEP 5 ✓] All tests passing
[STEP 6 ✓] PR opened → https://github.com/owner/repo/pull/99

────────────────────────────────────────────────────────────
```

**Bob IDE mode** — terminal shows a pointer, logs appear in the IDE:

```
╔═══════════════════════════════════════════════════════╗
║            Solvix — Autonomous Issue Fixer            ║
║            Mode: Bob IDE  (watch in IDE chat)         ║
╚═══════════════════════════════════════════════════════╝

[✓] Found 3 issue(s) assigned by Wilfred007

  👉  Switch to Bob IDE now — the workflow is starting in a new chat.
     Watch the chat panel for live step-by-step progress.
     You'll see [STEP N ✓] as each step completes.

[✓] Workflow sent to Bob IDE.
```

---

## Architecture

```
Issue Assigned
      │
      ▼
┌─────────────────────────────┐
│  Step 1: Trigger + Understand│  issue_read, get_comments
│  (produce written summary)   │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Step 2: Fork + Clone        │  fork_repository → git clone
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Step 3: Locate Code         │
│  ┌──────────┐ ┌───────────┐ │  PARALLEL SUBAGENTS
│  │ Keyword  │ │ Traceback │ │  search_code, get_repository_tree
│  │ Search   │ │ Tracer    │ │
│  └──────────┘ └───────────┘ │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Step 4: Implement Fix       │  Bob agent mode, local file edits
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Step 5: Verify              │
│  ┌──────────┐ ┌───────────┐ │  PARALLEL SUBAGENTS
│  │Run Tests │ │Write Test │ │  local test execution
│  │(existing)│ │(if missing)│ │
│  └──────────┘ └───────────┘ │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Step 6: Commit + Push + PR  │  create_branch, push_files,
│  (Closes #<issue-number>)    │  create_pull_request
└─────────────────────────────┘
```

---

## Project Structure

```
solvix/
├── solvix                           # ← ONE-COMMAND entry point
├── .env                             # Your credentials (BOB_API_KEY + GITHUB_PAT)
├── README.md
├── .bob/
│   └── SKILL.md                     # Bob skill — loads agent instructions
├── agent/
│   ├── orchestrator.md              # Master prompt: chains all 6 steps (single issue)
│   ├── multi_orchestrator.md        # Multi-issue: one branch, one PR
│   └── steps/
│       ├── 01_understand_issue.md
│       ├── 02_fork_clone.md
│       ├── 03_locate_code.md
│       ├── 04_fix_code.md
│       ├── 05_verify.md
│       └── 06_pr.md
│   └── subagents/
│       ├── locator_keyword.md
│       ├── locator_traceback.md
│       ├── verifier_run_tests.md
│       └── verifier_write_tests.md
├── scripts/
│   ├── bob_launch.sh                # Bob discovery + launch helper (sourced internally)
│   ├── run_agent.sh                 # Single-issue runner
│   ├── run_multi.sh                 # Multi-issue runner (auto-detects assigner)
│   ├── setup.sh                     # Environment validator (run via ./solvix setup)
│   ├── setup_approvals.sh           # Patches ~/.bob/mcp.json — alwaysAllow
│   └── discover_issues.sh           # Debug: list issues by assigner
└── demo/
    ├── seed_issues.md
    └── demo_script.md
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| **First run doesn't ask for environment choice** | Run `./solvix env` to trigger the picker manually |
| **Want to switch from CLI to IDE (or back)** | Run `./solvix env` and pick again — saved immediately |
| `Bob API key is required` | CLI mode only: add `BOB_API_KEY` to `.env` from https://bob.ibm.com/admin/apikeys |
| **No terminal output, nothing happening** | You're in IDE mode — switch to Bob IDE and check the Chat panel |
| **Bob IDE chat didn't open** | Bob IDE may not be running — open it first, then re-run |
| `GITHUB_PERSONAL_ACCESS_TOKEN is not set` | Add it to `.env` — create at https://github.com/settings/tokens |
| `PAT missing 'repo' scope` | Regenerate token with `repo` and `workflow` scopes |
| **Bob Shell CLI not found** | Install: `npm install -g @ibm/bob` then add `BOB_API_KEY` to `.env` |
| Issues not found | Run `./scripts/discover_issues.sh --repo owner/repo --assigned-by username` |

---

## Demo Flow (3–5 min)

1. Show the seeded repo and a clearly written open issue
2. Run `./solvix --repo owner/repo`
3. Narrate each logged step as it streams to the terminal
4. Highlight the two parallel subagent pairs (locate + verify)
5. Show the opened PR: diff, description, `Closes #N`
6. Show before/after step count

See [`demo/demo_script.md`](demo/demo_script.md) for the full narration guide.

---

## Submission Checklist

- [ ] Working prototype on a real or sandboxed repo you control
- [ ] Agent mode, parallel subagents, document understanding all visibly used
- [ ] At least one full issue → PR cycle completed and shown passing tests
- [ ] Before/after impact shown (time from assignment to PR)
- [ ] Demo video recorded
- [ ] Writeup with problem statement, architecture, metrics
- [ ] Repo/code link included in submission
