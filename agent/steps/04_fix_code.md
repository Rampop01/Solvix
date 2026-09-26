# Step 4 — Implement the Fix

**Inputs:** `ISSUE_SUMMARY` (Step 1), `CODE_LOCATIONS` (Step 3)
**Outputs:** Modified source file(s), a `CHANGE_SUMMARY` block

---

## Guiding Principles

- Make the **minimal correct change** — do not refactor surrounding code.
- Match the existing code style: indentation, naming conventions, comment style.
- Do not add logging, error handling, or comments beyond what is necessary.
- If the fix requires changing more than 3 files, pause and confirm with the user
  before proceeding — that is likely outside the intended scope.

---

## Actions

### 4.1 Re-read the target file(s)

For each HIGH-confidence entry in `CODE_LOCATIONS`, read the file fully around
the target lines (+/- 30 lines for context):

```bash
# Inside the cloned repo directory
cat -n <file>
```

or use `get_file_contents` if reading from the MCP layer.

### 4.2 Formulate the change

Before writing code, produce a brief `CHANGE_PLAN`:

```
CHANGE_PLAN
===========
File   : src/utils/parser.py
Line(s): 52–55
Action : Replace regex pattern to handle ISO 8601 timezone offsets (+HH:MM)
Reason : Issue states dates like "2024-01-15T10:00:00+05:30" are rejected
Risk   : Low — only changes the regex; existing tests still valid for UTC dates
```

### 4.3 Write the fix

Edit the file(s) in the cloned repo using Bob's agent file editing tools.

Follow the pattern:
- Read current content
- Apply the diff using the smallest possible change
- Re-read to confirm the change looks correct

### 4.4 Review the diff

```bash
git diff
```

The diff must:
- Show only the files listed in `CODE_LOCATIONS`
- Be coherent and non-breaking at a quick read
- Not accidentally include unrelated whitespace changes

### 4.5 Produce CHANGE_SUMMARY

```
CHANGE_SUMMARY
==============
Files changed : 1
  - src/utils/parser.py (+3 lines, -1 line)
Description  : Updated ISO 8601 date regex in parse_date() to accept
               timezone offsets in +HH:MM format (was UTC-only).
               Fixes: date strings with non-UTC offsets raised ValueError.
```

---

## Rules

- **Do not commit in this step.** Commit happens in Step 6.
- If you are unsure about the correct fix, state your uncertainty in `CHANGE_PLAN`
  and proceed with the most conservative interpretation of the issue.
- Do not modify test files in this step — Step 5 handles tests.

---

## Log

Print when complete:

```
[STEP 4 ✓] Fix written: <N> file(s) changed
            git diff: <+X lines, -Y lines>
```
