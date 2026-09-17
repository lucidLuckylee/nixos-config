# How the coding agents behave: Claude Code's settings, global memory and
# output style, the Claude→Codex handoff, and the shared plans repo that every
# machine clones. MCP servers for both tools live in mcp.nix.
{ pkgs, lib, config, ... }:
let
  plansRepo = "git@github.com:lucidLuckylee/plans.git";
  plansDir = "${config.home.homeDirectory}/Plans";

  # Plumbing the handoff skill calls: plans sync, Codex quota, codex exec.
  handoff = pkgs.writeShellApplication {
    name = "handoff";
    runtimeInputs = [
      pkgs.git pkgs.coreutils pkgs.python3 config.programs.codex.package
    ];
    text = builtins.replaceStrings [ "@plansRepo@" "@plansDir@" ]
      [ plansRepo plansDir ] (builtins.readFile ./agents/handoff.sh);
  };

  # ── Claude Code global settings (merged into ~/.claude/settings.json) ──
  claudeSettings = {
    model = "fable";
    outputStyle = "Terse";

    permissions = {
      allow = [
        "WebFetch(domain:github.com)"
        "WebFetch(domain:raw.githubusercontent.com)"
        "WebSearch"
      ];
      defaultMode = "auto";
    };

    sandbox = {
      filesystem = {
        allowRead = [ "/nix/store/**" ];
      };
    };

    enabledPlugins = {
      "ralph-loop@claude-plugins-official" = true;
      "dev-browser@dev-browser-marketplace" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
    };

    # Fresh plans on every session; the script only speaks up when it fails.
    hooks.SessionStart = [{
      matcher = "startup|resume";
      hooks = [{
        type = "command";
        command = "${handoff}/bin/handoff sync";
        timeout = 90;
      }];
    }];
  };

  claudeManagedSettings = pkgs.writeText "claude-managed-settings.json"
    (builtins.toJSON claudeSettings);
in {
  home.packages = [ handoff ];

  programs.claude-code = {
    enable = true;
    package = null; # shared.nix installs claude-code itself
    context = ./agents/claude/CLAUDE.md;
    outputStyles.terse = ./agents/claude/terse.md;
    skills.handoff =
      pkgs.replaceVars ./agents/claude/handoff/SKILL.md { inherit plansDir; };
  };

  programs.codex = {
    skills.implement-plan = ./agents/codex/implement-plan;
    # `handoff run` layers this over config.toml and overrides the effort.
    profiles.implement = {
      model = "gpt-6-astra";
      model_reasoning_effort = "high";
      model_verbosity = "low";
    };
  };

  # Merge managed Claude settings recursively, preserving other preferences.
  home.activation.setupClaudeSettings =
    lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
      CLAUDE_SETTINGS="$HOME/.claude/settings.json"
      mkdir -p "$HOME/.claude"
      # An earlier generation left a store symlink here; it would also make the
      # tmp-file rename below land in the store.
      [ -L "$CLAUDE_SETTINGS" ] && rm "$CLAUDE_SETTINGS"

      if [ -f "$CLAUDE_SETTINGS" ]; then
        # Recursive merge with the managed side winning, so a nested key Nix
        # does not name (an imperatively granted permission, say) survives.
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
          "$CLAUDE_SETTINGS" ${claudeManagedSettings} \
          > "$CLAUDE_SETTINGS.tmp" \
          && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
      else
        install -m 644 ${claudeManagedSettings} "$CLAUDE_SETTINGS"
      fi
    '';

  # Every machine gets the plans repo at rebuild; offline only warns.
  home.activation.clonePlans = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${handoff}/bin/handoff sync || true
  '';
}
