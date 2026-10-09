# Mac Qwen inference

The Mac serves Qwen3.5-9B Q5_K_M through llama.cpp with Metal, with the
vision projector disabled to leave memory for text context. The model
is downloaded at runtime into `~/Library/Application Support/mac-llm`, not the
Nix store. launchd runs the server as `lee`, with 32k context and one inference
slot; multiple local agent sessions share it and wait for that slot.
`caffeinate -i` prevents idle system sleep while the inference service runs;
the display can still sleep.

Authentication uses a random key created at service startup in
`~/.config/mac-llm/api-key` (directory 0700, file 0600). The client reads it over
SSH without printing it, so no manual key synchronization is needed. The API
listens only on Mac localhost port 8081. It is never forwarded by the router.

Linux `mac-code` and `mac-code-status` use the existing SSH credentials and pin
the same Mac host key as DesktopWake. Routing probes `192.168.1.190:22`, then
falls back to `home.munchy.gay:2223`. Only SSH needs to be publicly reachable.
If another LAN uses the same private address, force the public route:

```bash
MAC_LLM_ROUTE=public mac-code-status
MAC_LLM_ROUTE=public mac-code
```

Each process opens a separate loopback tunnel on a free local port and closes
it when the agent exits. The client never uploads your worktree. File access,
git and tests run where you invoke it; context sent to the model goes to your
Mac. The Mac client connects directly to localhost. Existing MCP services
retain their existing behavior, including their own external connections.

```bash
mac-code-status
cd ~/project
mac-code
# Normal Anthropic provider:
claude
```

The wrapper maps main and subagent model aliases to `qwen3.5-9b` for that process
only, including the managed Haiku subagent setting, and declares the actual
32k context limit to Claude, caps each response at 4096 tokens, and requests
auto-compaction at 24576 tokens to leave room for tool results and generation.
Only the core Bash, Read, Edit, Write, Glob, Grep and Skill tools are enabled.
Optional MCP servers and the managed browser/frontend/Rust plugins are disabled
for this process. In `pokebw2`, a fresh read-only request with the full catalogue
exceeded 40k tokens; the scoped launcher starts around 10k with the same project
instructions. It uses manual permission prompts: auto mode's separate safety
classifier also exceeded 32k in the live tool test.
Project CLAUDE.md, skills and safety hooks still load.
A checked-in Qwen template preserves non-leading
system messages that Claude injects; the original template throws HTTP 500
on them. This compatibility change was required by the live harness test. It clears conflicting
provider credentials. Existing Claude settings and permissions still load.
Avoid supplying conflicting `--model` or `--settings` flags. A 9B model's agent
reliability and the harness's context requirements must be assessed on real
work. Start a fresh `mac-code` session after updating the launcher; resuming an
oversized old conversation can still exceed the server's window. Keep file reads
and command output bounded. Use normal `claude` for tasks requiring much larger
context or stronger reasoning.

For independent concurrent work, create git worktrees and run one `mac-code`
per worktree. Inference is serialized to stay within the 16 GB Mac's memory.
Increase `--parallel` only after testing memory and throughput; llama.cpp's
context allocation must also be adjusted for the desired per-slot capacity.

Activation (not executed by the implementation):

```bash
# Laptop:
sudo nixos-rebuild switch --flake /home/lucy/NixOS#nixos
# Desktop, in the checkout containing these changes:
sudo nixos-rebuild switch --flake .#desktop
# Mac, in the checkout containing these changes:
sudo darwin-rebuild switch --flake .#mac
```

New Nix modules must be tracked with `git add` before Git-flake rebuilds.
For review builds, explicit `path:/absolute/checkout` includes unstaged files.
Model loading/downloads take time on first launch:

```bash
# On Mac:
tail -f ~/Library/Logs/mac-llm.log
sudo launchctl kickstart -k system/org.nixos.mac-llm
```

Away-from-home access needs the Mac awake, router SSH forwarding intact, and
DDNS working. The public SSH route was tested, but a separate external-network
test should be performed from a phone hotspot. No extra model HTTP firewall
port is needed. The existing DesktopWake key is restricted to its proxy command;
the client uses each machine's normal SSH identity, not that restricted key.

Sources checked 2026-10-09:
- https://huggingface.co/Qwen/Qwen3.5-9B
- https://huggingface.co/unsloth/Qwen3.5-9B-GGUF
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
