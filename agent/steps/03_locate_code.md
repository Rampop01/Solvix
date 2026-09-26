# Step 3 — Locate Relevant Code

**Inputs:** `ISSUE_SUMMARY` (from Step 1), cloned repo directory (from Step 2)
**Outputs:** `CODE_LOCATIONS` block — list of file paths + line ranges + rationale

---

## Method: Two Parallel Subagents

Spawn **both subagents simultaneously** to maximize search coverage.
Each returns a ranked list of candidate locations. You then merge and deduplicate.

```
Spawn subagents in parallel:
  A → agent/subagents/locator_keyword.md
  B → agent/subagents/locator_traceback.md
```

Pass both subagents the full `ISSUE_SUMMARY` and the `REPO` name.

---

## Merge Results

Once both subagents return:

1. Collect all candidate `(file, line_range, confidence)` tuples from both.
2. Deduplicate by file path.
3. If both subagents agree on a file → confidence = HIGH.
4. If only one subagent found it → confidence = MEDIUM.
5. Read the top HIGH+MEDIUM candidates with `get_file_contents` to confirm relevance.

---

## Produce CODE_LOCATIONS

```
CODE_LOCATIONS
==============
[1] File    : src/utils/parser.py
    Lines   : 45–78
    Symbol  : parse_date()
    Reason  : Keyword "parse_date" from issue title; both subagents agree
    Confidence: HIGH

[2] File    : tests/test_parser.py
    Lines   : 1–30
    Symbol  : test_parse_date (missing)
    Reason  : Subagent A: no test for this function
    Confidence: HIGH (test gap)

[3] File    : src/models/event.py
    Lines   : 12–20
    Symbol  : Event.__init__
    Reason  : Subagent B: stack trace points here
    Confidence: MEDIUM
```

---

## Rules

- Prefer **fewer, higher-confidence targets** over a long list of guesses.
- If both subagents return zero results → fall back to `get_repository_tree` and
  read top-level structure, then reason about likely locations from the issue summary.
- Always read the actual file content for every HIGH-confidence candidate before
  passing `CODE_LOCATIONS` to Step 4.

---

## Log

Print when complete:

```
[STEP 3 ✓] Located <N> candidate locations (<M> HIGH confidence)
            Primary target: <file>:<lines>
```
