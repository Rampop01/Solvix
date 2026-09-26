# Solvix — Master Orchestrator

> **Bob agent mode prompt.** Open this file in IBM Bob 2.0 → Agent mode.
> Provide `REPO` (owner/repo) and `ISSUE_NUMBER` before starting.

---

## Variables (fill in before running)

```
REPO=<owner>/<repo-name>
ISSUE_NUMBER=<number>
FORK_OWNER=<your-github-username>
TEST_CMD=<e.g. npm test | pytest | go test ./...>
```

---

## Execution Plan

You will execute the following six steps **in order**. Each step is documented in
`agent/steps/`. Before moving to the next step, confirm the current step succeeded
and log it clearly with `[STEP N ✓]`.

Do not proceed to a later step if an earlier step failed — report the blocker instead.

---

### [STEP 1] Understand the Issue

**Goal:** Produce a written summary of what needs to change before touching any code.

Follow: [`agent/steps/01_understand_issue.md`](steps/01_understand_issue.md)

**Completion check:** You have produced a structured `ISSUE_SUMMARY` block.

---

### [STEP 2] Fork + Clone

**Goal:** Fork the repository to `FORK_OWNER` and clone it locally.

Follow: [`agent/steps/02_fork_clone.md`](steps/02_fork_clone.md)

**Completion check:** Local clone exists and `git status` is clean.

---

### [STEP 3] Locate Relevant Code

**Goal:** Identify the exact files, functions, and lines that need to change.

Follow: [`agent/steps/03_locate_code.md`](steps/03_locate_code.md)

**Method:** Spawn **two parallel subagents**:
- `subagents/locator_keyword.md` — keyword/symbol search
- `subagents/locator_traceback.md` — error/traceback tracing

Merge their findings into a `CODE_LOCATIONS` block.

**Completion check:** At least one file+line range identified with confidence.

---

### [STEP 4] Implement the Fix

**Goal:** Write the minimal correct code change.

Follow: [`agent/steps/04_fix_code.md`](steps/04_fix_code.md)

**Completion check:** Files edited, `git diff` reviewed and makes sense.

---

### [STEP 5] Verify

**Goal:** Confirm the fix doesn't break anything; add a test if one is missing.

Follow: [`agent/steps/05_verify.md`](steps/05_verify.md)

**Method:** Spawn **two parallel subagents**:
- `subagents/verifier_run_tests.md` — run existing test suite
- `subagents/verifier_write_tests.md` — write a new test if coverage is missing

**Completion check:** All tests pass. `VERIFICATION_REPORT` produced.

---

### [STEP 6] Commit, Push, Open PR

**Goal:** Push fix to a branch on the fork, open a PR to the parent repo.

Follow: [`agent/steps/06_pr.md`](steps/06_pr.md)

**Completion check:** PR is open, contains `Closes #ISSUE_NUMBER`, diff is correct.

---

## Final Output

After Step 6 completes, print a summary:

```
╔══════════════════════════════════════════════════════╗
║                   SOLVIX — DONE                      ║
╠══════════════════════════════════════════════════════╣
║ Repo        : <REPO>                                 ║
║ Issue       : #<ISSUE_NUMBER>                        ║
║ Branch      : fix/issue-<ISSUE_NUMBER>               ║
║ PR URL      : <url>                                  ║
║ Tests       : PASSING                                ║
║ Steps taken : 6                                      ║
╚══════════════════════════════════════════════════════╝
```
