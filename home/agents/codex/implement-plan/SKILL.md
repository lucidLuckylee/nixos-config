---
name: implement-plan
description: Implement a plan file written by another agent, task by task, verify it, and report deviations. Use when asked to implement, execute, or carry out a plan, spec, or handoff file.
metadata:
  short-description: Implement a plan file task by task
---

# Implement a plan

The prompt names a plan file. Read all of it, then read every file listed under Context before editing.

- Implement each task in order, exactly as specified. No refactors, renames, comments, docs, or tests the plan does not ask for.
- Run each task's "Done when" check before moving on. Fix failures yourself and rerun the affected checks without asking. After two failed attempts on one task, stop and report.
- Run everything under Verification at the end. Never weaken, skip, or delete a test to make it pass.
- Stop and report when a Context claim is false, a task needs a decision Design does not cover, or a "Stop and report if" condition is met. Do not guess at design.
- Do not commit or push unless the plan says so.

## Report

Reply with only this, under 20 lines:

STATUS: DONE, DONE_WITH_DEVIATIONS, or BLOCKED
Changed: one path per line
Verification: each command with its result; paste failing output verbatim
Deviations: what differs from the plan and why, or "none"
Open: decisions needed, or "none"
