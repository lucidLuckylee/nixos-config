
# Knowledge base
- `~/Plans` is a git repo shared by every machine and by Claude and Codex: plans, decisions, and things learnt. Layout: `<project>/<yyyy-mm-dd>-<topic>.md`.
- Before non-trivial work in a project, check `~/Plans/<project>/` for relevant notes.
- Write a note when you learn something non-obvious that the code and git history do not show: a design decision and its reason, a dead end, a gotcha, a plan. Keep it short; update an existing note instead of adding a duplicate.
- After writing, commit and push: `git -C ~/Plans add -A && git -C ~/Plans commit -m "<project>: <topic>" && git -C ~/Plans pull --rebase && git -C ~/Plans push`.
