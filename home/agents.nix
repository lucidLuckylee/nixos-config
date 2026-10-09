# How the coding agents behave: Claude Code's settings, global memory
# and output style. MCP servers for both tools live in mcp.nix.
{ pkgs, lib, config, ... }:
let
  plansRepo = "git@github.com:lucidLuckylee/plans.git";
  plansDir = "${config.home.homeDirectory}/Plans";
  knowledgeBase = builtins.readFile ./agents/knowledge-base.md;

  # ── Claude Code global settings (merged into ~/.claude/settings.json) ──
  claudeSettings = {
    model = "sonnet";
    env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku";
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
      "dev-browser@dev-browser-marketplace" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "frontend-design@claude-plugins-official" = true;
    };

    # Fresh notes on every session; a failed pull just leaves them as they were.
    hooks.SessionStart = [{
      matcher = "startup|resume";
      hooks = [{
        type = "command";
        command = "git -C ${plansDir} pull --ff-only --quiet || true";
        timeout = 30;
      }];
    }];
  };

  claudeManagedSettings = pkgs.writeText "claude-managed-settings.json"
    (builtins.toJSON claudeSettings);
in {
  imports = [ ./kaggle-llm.nix ./mac-llm.nix ];

  programs.claude-code = {
    enable = true;
    package = null; # shared.nix installs claude-code itself
    context = builtins.readFile ./agents/claude/CLAUDE.md + knowledgeBase;
    outputStyles.terse = ./agents/claude/terse.md;
  };

  programs.codex.context = knowledgeBase;

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

  # Every machine gets the notes repo at rebuild; offline only warns.
  home.activation.clonePlans = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    [ -d ${plansDir}/.git ] || ${pkgs.git}/bin/git clone --quiet ${plansRepo} ${plansDir} || true
  '';
}
