---
name: handoff
description: Plan a change in this repo, save the plan to the shared plans repo, and have Codex (GPT-6 Astra) implement it while Claude reviews. Use when the user asks to hand off, delegate to Codex, or plan-then-implement.
argument-hint: <what to build or change>
effort: xhigh
allowed-tools: Bash(handoff *), Bash(git *)
---

Task: $ARGUMENTS

## Plan

- Read the code the change touches before deciding anything. Cite exact paths and symbols.
- Make the design decisions yourself. Ask the user only for choices they must own (product behaviour, irreversible changes), all in one AskUserQuestion round.
- If the diff would fit in one sentence, skip the handoff: implement it directly and stop.

Write the plan to `@plansDir@/<repo>/<YYYY-MM-DD>-<slug>.md`, where `<repo>` is the basename of the git root. Keep it under 200 lines, in this shape:

    # <title>
    Repo: <git root>   Branch: <branch>   Date: <date>

    ## Goal
    One paragraph: what is different when this is done.

    ## Non-goals
    - what the implementer must not touch

    ## Context
    - `path/file.rs`, `fn name`: what it does today and why it changes

    ## Design
    Decisions with one line of rationale each. Exact signatures and types that must exist afterwards.

    ## Tasks
    ### 1. <name>
    Files: `a.rs`, `b.rs`
    Steps: numbered and concrete, two to five per task
    Done when: command plus expected outcome

    ## Verification
    Commands to run at the end, with expected results.

    ## Stop and report if
    - an assumption in Context is false
    - a task needs a decision Design does not cover
    - a Done-when check still fails after two attempts

Every task names its files. No "TBD", no "similar to task N". Then run `handoff push <file> "Plan: <title>"`.

## Implement

1. Run `handoff status`. Exit code 2 means Codex is out of quota: implement the plan yourself and say so.
2. Choose Codex's reasoning effort: `medium` when every task is mechanical and fully specified, `high` for ordinary logic, `xhigh` when tasks leave algorithmic or concurrency decisions to the implementer or touch consensus, crypto, or money.
3. From the repo root run `handoff run <plan> <effort>` in the background and wait for it to finish. Do not poll.
4. If it exits non-zero or the report says BLOCKED, implement the remaining tasks yourself.

## Review

- Check `git diff` against the plan: every Done-when met, nothing outside the tasks changed, Verification passes. Fix small gaps directly; for larger ones fix the plan and run Codex again.
- Append `## Outcome` to the plan (status, deviations, Codex's report) and `handoff push` it.
- Report to the user in under ten lines: what changed, verification result, deviations.
