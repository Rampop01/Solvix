# Step 5 — Verify

**Inputs:** `CHANGE_SUMMARY` (Step 4), `TEST_CMD`, cloned repo directory
**Outputs:** `VERIFICATION_REPORT` block. All tests must pass before Step 6.

---

## Method: Two Parallel Subagents

Spawn **both subagents simultaneously**:

```
Spawn subagents in parallel:
  A → agent/subagents/verifier_run_tests.md   (run existing suite)
  B → agent/subagents/verifier_write_tests.md  (add test if coverage missing)
```

Pass both subagents:
- The `CHANGE_SUMMARY`
- The `TEST_CMD`
- The cloned repo path
- The `CODE_LOCATIONS` (so the test-writer knows what to cover)

---

## Sequencing Rule

Subagent A runs the **existing** tests immediately (they should still pass).
Subagent B **writes a new test** (if needed) and then runs the suite again.

If Subagent B adds a new test file, merge it back into the working tree before
the final test run. The final suite run must include **both** old and new tests.

---

## Produce VERIFICATION_REPORT

```
VERIFICATION_REPORT
===================
Existing tests : PASS  (42 passed, 0 failed, 0 errors)
New test added : YES → tests/test_parser.py::test_parse_date_with_offset
New test result: PASS
Full suite     : PASS  (43 passed, 0 failed, 0 errors)
Coverage delta : +1 test covering parse_date() with timezone offsets
```

---

## Failure Handling

| Situation | Action |
|-----------|--------|
| Existing test fails after fix | Stop. Report the failing test. Revert or amend the fix in Step 4 and re-run Step 5. |
| New test fails | The fix is incomplete. Return to Step 4 with the failing test as additional context. |
| Test command not found | Report the blocker — do not open a PR with unverified code. |
| No test framework in repo | Document this in the report; note that manual verification is needed. |

---

## Rules

- **Never open a PR if any test is failing.**
- The new test (if written) must be on the same fix branch, committed alongside the fix.
- Do not modify existing tests to make them pass — that masks real failures.

---

## Log

Print when complete:

```
[STEP 5 ✓] Verification passed
            Suite: <N> tests, 0 failures
            New test: <YES/NO> — <test name if yes>
```
