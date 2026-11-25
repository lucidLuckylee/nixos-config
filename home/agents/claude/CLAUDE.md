# Code
- Only make changes that are directly requested or clearly necessary. A bug fix does not need surrounding cleanup; a one-shot operation does not need a helper.
- Do the simplest thing that works. No abstractions, feature flags, or backwards-compatibility shims when you can just change the code.
- Do not add error handling, fallbacks, or validation for cases that cannot happen. Validate at system boundaries only.
- Write code that reads like the surrounding code: match its comment density, naming, and idiom. Comment only where the logic is not self-evident.
- Do not add docstrings, comments, or type annotations to code you did not change.
- If you find a pre-existing bug or unrelated issue, leave it and mention it as a follow-up.
- Add tests only where the task asks for them or the repo already tests this kind of change. Do not turn scratch checks into permanent test files.
- Edit files surgically rather than rewriting them. Inside the repo, delete temporary files you created and create documentation files only when asked; notes and reusable scripts go in `~/Plans` (see Knowledge base).

# Models
- Pick each subagent's model yourself: `haiku` for file lookups and bulk reads, `sonnet` for search and discovery that needs judgment, `opus` for design, review and hard debugging.
- Start `fable` agents when you judge the task needs them.

# Rust builds
- While iterating, scope commands to the crate you changed (`cargo check -p <crate>`, `cargo nextest run -p <crate>`).
- Prefer `cargo check` or `cargo clippy` over building test binaries you do not need to run.
- Run the full workspace checks once, at the end.
- All worktrees share one target dir, `~/.cache/cargo-target`: find binaries there, not in `./target`.
- When cargo prints "Blocking waiting for file lock", another worktree is building: wait for it.
- Free disk with `cargo clean -p <crate>`; run a full `cargo clean` only when asked.
- Run tests with `cargo nextest run` where available; it skips doctests, so use `cargo test --doc` for those.

# Nix
- In a repo with a `flake.nix`, enter its dev shell before running anything that needs project tooling (`nix develop -c <cmd>`, or via direnv if `.envrc` is present) so all dependencies are available.
- When the project needs a tool or library installed on the machine, add it to the repo's `flake.nix` (dev shell for development tools, package inputs for runtime dependencies) instead of installing it globally or asking the user to.
