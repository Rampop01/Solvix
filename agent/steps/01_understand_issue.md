# Step 1 — Understand the Issue

**Inputs:** `REPO`, `ISSUE_NUMBER`
**Outputs:** `ISSUE_SUMMARY` block (structured text)

---

## Actions

### 1.1 Fetch the issue

Use the GitHub MCP tool `get_issue`:

```
tool: get_issue
owner: <REPO owner>
repo:  <REPO name>
issue_number: <ISSUE_NUMBER>
```

Capture: title, body, labels, assignees, state.

### 1.2 Fetch all comments

```
tool: list_issue_comments
owner: <REPO owner>
repo:  <REPO name>
issue_number: <ISSUE_NUMBER>
```

Read every comment. Note any that contain:
- Stack traces or error messages
- File paths or function names mentioned
- Acceptance criteria or reproduction steps
- Links to external docs or related issues

### 1.3 Fetch linked documents (if any)

If the issue body or comments reference specific files in the repo (e.g. `src/foo.py`)
or external URLs, fetch and read them:

```
tool: get_file_contents
owner: <REPO owner>
repo:  <REPO name>
path:  <referenced file path>
```

### 1.4 Produce ISSUE_SUMMARY

Write a structured block:

```
ISSUE_SUMMARY
=============
Title       : <issue title>
Number      : #<ISSUE_NUMBER>
Type        : [Bug | Feature | Docs | Refactor]
Reproduction: <minimal steps to reproduce, if bug>
Error       : <exact error message / stack trace, if present>
Expected    : <what should happen>
Actual      : <what currently happens>
Hints       : <any file paths, function names, or keywords mentioned>
Acceptance  : <definition of done from the issue or inferred>
```

---

## Rules

- Do **not** guess about the codebase yet — only use information from the issue itself.
- If the issue is ambiguous, note the ambiguity in `Hints` and make the safest assumption.
- If reproduction steps are present, quote them verbatim under `Reproduction`.

---

## Log

Print when complete:

```
[STEP 1 ✓] Issue understood: "<title>" — Type: <type>
```
