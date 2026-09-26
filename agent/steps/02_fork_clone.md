# Step 2 — Fork + Clone

**Inputs:** `REPO` (owner/repo), `FORK_OWNER` (your GitHub username)
**Outputs:** Local directory `<repo-name>/` with a clean working tree

---

## Actions

### 2.1 Fork the repository

```
tool: fork_repository
owner: <REPO owner>
repo:  <REPO name>
```

The fork will be created at `github.com/<FORK_OWNER>/<repo-name>`.

Wait for the fork to be ready (the tool returns the fork's metadata including the
`clone_url`). Record:

```
FORK_URL=https://github.com/<FORK_OWNER>/<repo-name>.git
PARENT_URL=https://github.com/<REPO owner>/<repo-name>.git
```

### 2.2 Clone the fork locally

```bash
git clone $FORK_URL
cd <repo-name>
git remote add upstream $PARENT_URL
git fetch upstream
```

> **Why add upstream?** We branch off `upstream/main` (or `upstream/master`) so our
> fix is based on the latest parent state, not whatever the fork's default branch is.

### 2.3 Determine the default branch

```bash
git remote show upstream | grep 'HEAD branch'
```

Record as `DEFAULT_BRANCH` (usually `main` or `master`).

### 2.4 Create a fix branch

Name the branch `fix/issue-<ISSUE_NUMBER>`:

```bash
git checkout -b fix/issue-<ISSUE_NUMBER> upstream/<DEFAULT_BRANCH>
```

### 2.5 Verify

```bash
git status          # should show: On branch fix/issue-<N>, nothing to commit
git log --oneline -3
```

---

## Rules

- Always branch off the **parent** repo's default branch via `upstream`, not the fork's
  potentially stale default branch.
- Do not commit anything in this step — the working tree must be clean.
- If the fork already exists (tool returns 422), that is fine — continue with clone.

---

## Log

Print when complete:

```
[STEP 2 ✓] Forked → <FORK_URL>
            Cloned → ./<repo-name>
            Branch → fix/issue-<ISSUE_NUMBER> (based on upstream/<DEFAULT_BRANCH>)
```
