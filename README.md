# Solvix
### IBM Bob 2.0 Hackathon — Project 2

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

### 1. IBM Bob 2.0
- Agent mode enabled
- Subagent spawning enabled (approve during demo or enable auto-approve)

### 2. GitHub MCP Server
Add to Bob's MCP configuration (Settings → MCP Servers → Add):

**Remote (recommended for demo):**
```json
{
  "type": "remote",
  "url": "https://api.githubcopilot.com/mcp/",
  "headers": {
    "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
  }
}
```

**Local via Docker:**
```bash
docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN \
  ghcr.io/github/github-mcp-server
```

Required toolsets: `repos`, `issues`, `pull_requests`, `git`

### 3. GitHub PAT
Scopes required: `repo` (full), `workflow` (if target repo uses Actions)

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
```

### 4. Target Repository
Use a repo you own or a sandboxed fork. Seed it with 2–3 well-scoped issues.
See [`demo/seed_issues.md`](demo/seed_issues.md) for templates.

### 5. Runnable Test Environment
Bob (or a subagent) must be able to execute the repo's test command.
Docker is recommended:
```bash
# Example for a Node.js repo
docker run --rm -v $(pwd):/app -w /app node:20 npm test
```

---

## Quick Start

```bash
# 1. Validate environment
./scripts/setup.sh

# 2. Run the agent on an issue
./scripts/run_agent.sh --repo owner/repo-name --issue 42

# Or trigger manually inside Bob:
# Open agent/orchestrator.md in Bob → Agent mode → provide REPO and ISSUE_NUMBER
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
├── README.md
├── .bob/
│   └── SKILL.md                     # Bob skill — loads agent instructions
├── agent/
│   ├── orchestrator.md              # Master prompt: chains all 6 steps
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
│   ├── run_agent.sh
│   └── setup.sh
└── demo/
    ├── seed_issues.md
    └── demo_script.md
```

---

## Demo Flow (3–5 min)

1. Show the seeded repo and a clearly written open issue
2. Run `./scripts/run_agent.sh --repo owner/repo --issue N`
3. Narrate each logged step as it streams
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
