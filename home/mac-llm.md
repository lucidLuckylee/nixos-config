# Mac Qwen inference

The Mac serves Qwen3.5-9B Q5_K_M for coding (localhost 8081, 224k context)
and **Mapika/decider-2b v11 Q8_0** for browser action selection (localhost 8082,
8k decision context). Both use llama.cpp's Metal backend. Decider is a System-One
classifier, not a chat model: each request renders the official plain state-first
prompt, calls `llama_decode` exactly once, reads the option-letter logits at the
answer slot, and applies v11's fitted Choice temperature (1.164). No answer token
is generated. All candidate actions compete in that one forward pass.

Decider uses a 256-token physical microbatch to reduce Metal compute workspace;
the 8k logical batch/context and single `llama_decode` readout are unchanged.
Long snapshots are processed internally in smaller chunks, which can trade
throughput for lower memory usage. The former 2048-token microbatch reserved
about 2 GB of Metal compute buffers even for short browser decisions.
Measured on the M4: the new workspace is 254.51 MiB (previously 2036.09 MiB);
the context cache remains 96 MiB and the calibrated single-decode readout works.

Qwen's limit is 229376 tokens (224 × 1024), with one inference slot. Its K/V
cache uses Q8_0 rather than F16 to limit memory use: estimated full-attention
cache allocation is 3.72 GiB rather than 7 GiB at this window. The recurrent
state, model weights and compute workspace are additional. Cache quantization
changes precision and may affect output quality. This larger configuration was
built without activating it; memory headroom and long-context throughput have
not been measured. Long uncached prompts can take several minutes on the M4.

The weights and `decider_config.json` are pinned to the same Hugging Face revision
`ff2e5e687327eda9ac34e9a3ca84d3f400672c87`; runtime downloads verify SHA256
before publication. Decider Q8 weighs 2.0 GB and is the project's recommended
GGUF precision. Qwen's vision projector remains disabled. Downloads live under
`~/Library/Application Support/mac-llm`, outside the Nix store. launchd runs
both servers as `lee`; concurrent clients queue separately for each model.
`caffeinate -i` prevents idle system sleep while the inference service runs;
the display can still sleep.

Authentication uses a random key created at service startup in
`~/.config/mac-llm/api-key` (directory 0700, file 0600). The client reads it over
SSH without printing it, so no manual key synchronization is needed. The API
listens only on Mac localhost ports 8081 and 8082. Neither is forwarded by
the router. Both daemons share the same atomically created runtime key.

Linux `mac-code` and `mac-code-status` use the existing SSH credentials and pin
the same Mac host key as DesktopWake. Routing probes `192.168.1.190:22`, then
falls back to `home.munchy.gay:2223`. Only SSH needs to be publicly reachable.
If another LAN uses the same private address, force the public route:

```bash
MAC_LLM_ROUTE=public mac-code-status
MAC_LLM_ROUTE=public mac-code
```

Each process opens separate loopback forwards for both models on free local
ports and closes the tunnel when the agent exits. The client never uploads your
worktree. File access,
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
224k context limit to Claude, caps each response at 4096 tokens, and requests
auto-compaction at 196608 tokens (192k) to leave room for tool results and generation.
Only the core Bash, Read, Edit, Write, Glob, Grep and Skill tools are enabled.
The coding model sees a single `browser_task` MCP tool. Qwen supplies `task`,
`url`, `done_when` (observable success condition), and optionally `inputs`
(mapping field labels to literal text/dropdown values). The Python controller
opens the URL in local Nix-managed Firefox, takes an accessibility snapshot,
and enumerates concrete clicks, supplied input values, Enter, back, scrolling,
finish and blocked actions. Decider scores those candidates via `/v1/systemone`
with a Jev-shaped Choice field; the controller executes the winning action and
repeats against a fresh snapshot. Decider never plans or generates text.

The result contains page evidence and a compact action/confidence trace, including
`forward_passes: 1` and `generated_tokens: 0` for each decision. Finish is a model
judgment: Qwen must check the returned evidence before claiming success. Page
content is untrusted observations, not instructions; this is still a model and
can choose poorly. No screenshots, browser JavaScript evaluation or hosted browser
service are used. The browser is headless with an isolated profile per coding
session; artifacts live in a temporary directory outside the repository.
Tasks are capped at 16 decisions and five minutes (scoped MCP timeout six minutes).
The current bounded candidate set includes up to 60 page actions; complex pages
or unnamed fields may need a narrower task or another delegation with supplied
input labels. Only browser context, not source files, goes to Decider.

The scoped configuration is generated by Home Manager at
`~/.config/mac-llm/mcp.json`; the wrapper uses the matching store asset, so review
builds can run without activation. Context7 stays out: no prior Claude tool
calls were found locally before the investigation. Other MCP servers and the
managed browser/frontend/Rust plugins stay disabled in `mac-code`.
A fresh `pokebw2` request with the full catalogue exceeded 40k tokens; the
scoped launcher keeps the same project
instructions. It uses `bypassPermissions`, as requested, to skip permission
prompts and auto mode's separate safety classifier, which exceeded 32k in the
live tool test. This applies only to `mac-code`; normal `claude` keeps its
existing permission mode.
Project CLAUDE.md, skills and safety hooks still load.
A checked-in Qwen template preserves non-leading
system messages that Claude injects; the original template throws HTTP 500
on them. This compatibility change was required by the live harness test. It clears conflicting
provider credentials. Existing Claude settings and permissions still load.
Avoid supplying conflicting `--model` or `--settings` flags. A 9B model's agent
reliability and the harness's context requirements must be assessed on real
work. Start a fresh `mac-code` session after updating the launcher; resuming an
oversized old conversation can still exceed the server's window. Keep file reads
and command output bounded. Use normal `claude` for tasks requiring stronger
reasoning.

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
tail -f ~/Library/Logs/mac-browser-llm.log
sudo launchctl kickstart -k system/org.nixos.mac-browser-llm
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

The local MCP controller is `home/mac-browser.py`. The Mac service is
`machines/mac/decider-server.py` with `decider.cpp`: a small native Choice-only
adapter for the official GGUF readout. This avoids pulling torch, transformers
and a second globally installed Python environment onto the 16 GB Mac. The
native scorer links against the same declarative llama.cpp package as Qwen.
It exposes authenticated `GET /health` and `POST /v1/systemone` (one Choice field,
2..255 candidates, all scored together). It rejects oversized decisions rather
than silently truncating task context. These are decision endpoints, not an
OpenAI chat-completion API.

Example in a fresh `mac-code` session:

> Use the browser to open http://127.0.0.1:18765, click Test action, and check
> that the heading becomes PLAYWRIGHT_CLICK_OK.

Sources for the Decider format, calibration and recommended weights:
- https://huggingface.co/Mapika/decider-2b-GGUF
- https://huggingface.co/Mapika/decider-2b
- https://github.com/Mapika/decider/blob/main/decider/prompt.py
- https://github.com/Mapika/decider/blob/main/decider/engine_gguf.py
