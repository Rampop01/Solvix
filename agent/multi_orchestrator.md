# Solvix — Multi-Issue Orchestrator

> **Bob agent mode prompt.** Open this file in IBM Bob 2.0 → Agent mode.
> Run `./scripts/run_multi.sh --repo owner/repo --assigned-by username` first —
> it auto-discovers the issues and pre-loads all variables below.

---

## Variables (pre-loaded by run_multi.sh)

```
REPO=<owner>/<repo-name>
ISSUE_NUMBERS=<e.g. "12 15 18 21">   ← all issues found, space-separated
BRANCH=fix/issues-<N1>-<N2>-<N3>...  ← one shared branch for all fixes
FORK_OWNER=<your-github-username>
TEST_CMD=<e.g. npm test | pytest | AUTO>
ASSIGNED_BY=<who assigned the issues>
```

---

## Strategy: One Branch — One PR — Closes All Issues

All fixes go onto **one branch**. One PR is opened at the end.
The PR body will contain a `Closes #N` line for every issue.

This means:
- The maintainer reviews one PR
- All issues are closed automatically when it merges
- The diff is grouped logically by feature/bug area

---

## Execution Plan

### [PHASE 1] Setup — Fork + Clone (once, shared by all issues)

Follow [`agent/steps/02_fork_clone.md`](steps/02_fork_clone.md) using `BRANCH` as the branch name.

> Do this **once**. All issue fixes share this single cloned repo and branch.

**Completion check:** Branch `BRANCH` exists locally, working tree is clean.

---

### [PHASE 2] Per-Issue Loop

For **each issue number** in `ISSUE_NUMBERS`, run the following sub-cycle in order.
Complete all steps for issue N before starting issue N+1.

```
For each ISSUE in ISSUE_NUMBERS:
  ├── [STEP A] Understand the issue
  ├── [STEP B] Locate relevant code  (2 parallel subagents)
  ├── [STEP C] Implement the fix
  └── [STEP D] Quick verify (run tests after each fix)
```

#### [STEP A] Understand Issue #N
Follow [`agent/steps/01_understand_issue.md`](steps/01_understand_issue.md)
Produce `ISSUE_SUMMARY_<N>` for this issue.

Log: `[ISSUE #N — STEP A ✓] Understood: "<title>"`

#### [STEP B] Locate Code for Issue #N
Follow [`agent/steps/03_locate_code.md`](steps/03_locate_code.md)
Spawn 2 parallel subagents. Produce `CODE_LOCATIONS_<N>`.

Log: `[ISSUE #N — STEP B ✓] Located: <file>:<lines>`

#### [STEP C] Fix Issue #N
Follow [`agent/steps/04_fix_code.md`](steps/04_fix_code.md)
Write the minimal fix. Produce `CHANGE_SUMMARY_<N>`.

> **Important:** Do NOT commit after each fix. Accumulate all changes on the branch.
> All fixes will be committed together in Phase 3.

Log: `[ISSUE #N — STEP C ✓] Fix written: <N files changed>`

#### [STEP D] Quick Verify After Each Fix
Run the test suite after each individual fix to catch regressions early:

```bash
<TEST_CMD>
```

If tests fail after fixing issue N → fix the regression before moving to issue N+1.

Log: `[ISSUE #N — STEP D ✓] Tests passing after this fix`

---

### [PHASE 3] Final Verification (all fixes together)

Once all issues are fixed, run the **full verification** with all changes combined:

Follow [`agent/steps/05_verify.md`](steps/05_verify.md)

Spawn 2 parallel subagents:
- Run full existing test suite
- Write any missing tests (one per issue if needed)

**All tests must pass before Phase 4.**

Log: `[PHASE 3 ✓] Full suite passing — all <N> issues fixed and verified`

---

### [PHASE 4] Commit + Push + Open ONE PR

#### Commit all fixes together

```bash
git add -A
git status   # confirm all intended files are staged
git commit -m "fix: resolve <N> assigned issues (#<N1>, #<N2>, ...)

<2–3 sentence summary of all changes made.>

Closes #<N1>
Closes #<N2>
Closes #<N3>
..."
```

Every issue number must appear on its own `Closes #N` line in the commit message.

#### Push

```bash
git push origin <BRANCH>
```

#### Compose the PR description

Use this template:

```markdown
## Summary

This PR resolves <N> issues assigned by @<ASSIGNED_BY>.

## Changes

### Closes #<N1> — <issue title>
- `<file>`: <what changed>

### Closes #<N2> — <issue title>
- `<file>`: <what changed>

### Closes #<N3> — <issue title>
- `<file>`: <what changed>

## Verification

- [x] Full test suite passes (<total> tests, 0 failures)
- [x] New tests added where coverage was missing

## Linked Issues

Closes #<N1>
Closes #<N2>
Closes #<N3>
```

#### Open the PR

```
tool: create_pull_request
owner:  <REPO owner>
repo:   <REPO name>
title:  "fix: resolve <N> issues (#<N1>, #<N2>, ...)"
body:   <filled PR template above>
head:   <FORK_OWNER>:<BRANCH>
base:   <DEFAULT_BRANCH>
draft:  false
```

---

## Final Summary

Print when complete:

```
╔══════════════════════════════════════════════════════╗
║              SOLVIX — MULTI-ISSUE DONE               ║
╠══════════════════════════════════════════════════════╣
║ Repo        : <REPO>                                 ║
║ Issues fixed: #<N1>, #<N2>, #<N3>...                ║
║ Branch      : <BRANCH>                               ║
║ PR URL      : <url>                                  ║
║ Tests       : PASSING                                ║
║ PR closes   : <N> issues automatically               ║
╚══════════════════════════════════════════════════════╝
```
