
# Knowledge base
- `~/Plans` is a git repo shared by every machine and by Claude: plans, decisions, and things learnt. Layout: `<project>/<yyyy-mm-dd>-<topic>.md`. `<project>` is the repo name of the `upstream` remote (else `origin`, else the main checkout's directory name), never a worktree's name; reuse an existing folder in `~/Plans` before creating one.
- Before non-trivial work in a project, check `~/Plans/<project>/` for relevant notes.
- Write a note when you learn something non-obvious that the code and git history do not show: a design decision and its reason, a dead end, a gotcha, a plan. Keep it short; update an existing note instead of adding a duplicate.
- Keep reusable scripts and reference material for a project in `~/Plans/<project>/tools/` (one flat folder per project): temporary scripts, queries, repro steps, and data notes that could save a rewrite later.
- Before writing a new helper script for a project, check `~/Plans/<project>/tools/` for an existing one. Give each file a short name and a one-line comment saying what it does.
- Do not store secrets, keys, or credentials there.
- Subagents read `~/Plans` but leave writing to the main agent: report anything worth noting in your result.
- After writing, commit and push: `git -C ~/Plans add <the files you wrote> && git -C ~/Plans commit -m "<project>: <topic>" && git -C ~/Plans pull --rebase && git -C ~/Plans push`.
