# Shared MCP server definitions for Claude and Codex. Activation merges managed
# settings into writable files so application state and trust entries survive.
{ pkgs, lib, config, ... }:
let
  npx = "${pkgs.nodejs}/bin/npx";
  uvx = "${pkgs.uv}/bin/uvx";

  # ── Rust MCP server packages ──────────────────────────────────────
  rust-mcp-server = pkgs.rustPlatform.buildRustPackage {
    pname = "rust-mcp-server";
    version = "0.3.3";
    src = pkgs.fetchFromGitHub {
      owner = "Vaiz";
      repo = "rust-mcp-server";
      rev = "v0.3.3";
      hash = "sha256-MpVK9uha/5zJPMAiF2gXtPqBLge7J7FqnvGBZMAAbHQ=";
    };
    cargoHash = "sha256-9o6dyOR+R6Pz7v1tsq3vP5KjCu2wT/ALnNFjuhuETdY=";
  };

  rust-analyzer-mcp = pkgs.rustPlatform.buildRustPackage {
    pname = "rust-analyzer-mcp";
    version = "0.2.0";
    src = pkgs.fetchFromGitHub {
      owner = "zeenix";
      repo = "rust-analyzer-mcp";
      rev = "v0.2.0";
      hash = "sha256-brnzVDPBB3sfM+5wDw74WGqN5ahtuV4OvaGhnQfDqM0=";
    };
    cargoHash = "sha256-7t4bjyCcbxFAO/29re7cjoW1ACieeEaM4+QT5QAwc34=";
    doCheck = false;
  };

  # ── Claude Code global settings (merged into ~/.claude/settings.json) ──
  claudeSettings = {
    model = "fable";
    outputStyle = "Concise";

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
  };

  # ── GitHub MCP wrapper (sources PAT from pass) ────────────────────
  githubMcpStart = pkgs.writeShellScript "github-mcp-start" ''
    set -euo pipefail
    export PATH="${pkgs.gnupg}/bin:$PATH"
    export GITHUB_PERSONAL_ACCESS_TOKEN="$(${pkgs.pass}/bin/pass show claude-mcp/github/pat)"
    exec ${npx} -y @modelcontextprotocol/server-github
  '';

  # ── MCP Servers (merged into ~/.claude.json) ──────────────────────
  mcpServers = {
    # Rust: cargo check/build/test/clippy/fmt
    "rust-mcp-server" = {
      command = "${rust-mcp-server}/bin/rust-mcp-server";
      args = [];
    };
    # Rust: go-to-definition, find references, diagnostics
    "rust-analyzer" = {
      command = "${rust-analyzer-mcp}/bin/rust-analyzer-mcp";
      args = [];
    };

    # Bitcoin tools, downloaded through npx.
    bitcoin = {
      command = npx;
      args = [ "-y" "bitcoin-mcp" ];
    };

    # Web: MDN CSS docs and browser compatibility data
    css = {
      command = npx;
      args = [ "-y" "css-mcp" ];
    };

    # Reasoning: multi-step problem decomposition
    "sequential-thinking" = {
      command = npx;
      args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
    };

    # Persistent memory across sessions
    memory = {
      command = npx;
      args = [ "-y" "@modelcontextprotocol/server-memory" ];
    };
    # File system operations
    filesystem = {
      command = npx;
      args = [ "-y" "@modelcontextprotocol/server-filesystem" config.home.homeDirectory ];
    };
    # HTTP fetch
    fetch = {
      command = uvx;
      args = [ "mcp-server-fetch" ];
    };

    # GitHub: cross-repo issues, PRs, code search, file viewing
    github = {
      command = "${githubMcpStart}";
      args = [];
    };

    # Context7: up-to-date library/crate docs on demand
    context7 = {
      command = npx;
      args = [ "-y" "@upstash/context7-mcp" ];
    };

    # Use the packaged Playwright MCP server.
    playwright = {
      command = "${pkgs.playwright-mcp}/bin/playwright-mcp";
      args = [];
    };
  };

  mcpConfigFile = pkgs.writeText "claude-mcp-servers.json"
    (builtins.toJSON mcpServers);

  claudeManagedSettings = pkgs.writeText "claude-managed-settings.json"
    (builtins.toJSON claudeSettings);

  # Reuse the server definitions for Codex.
  tomlFormat = pkgs.formats.toml { };
  codexManagedConfig = tomlFormat.generate "codex-managed-config.toml" {
    # Allow optional servers time to finish startup.
    mcp_optional_startup_grace_ms = 10000;
    # Allow npm downloads and compilation before the MCP initialize response.
    mcp_servers =
      lib.mapAttrs (_: s: s // { startup_timeout_sec = 60; }) mcpServers;
  };

  # Python because it is the one thing at hand that can round-trip TOML:
  # tomllib reads it (stdlib), tomli-w writes it back.
  codexMergePython = pkgs.python3.withPackages (ps: [ ps.tomli-w ]);
  codexMergeScript = pkgs.writeText "codex-config-merge.py" ''
    import os, sys, tomllib
    import tomli_w

    managed_path, cfg_path = sys.argv[1], sys.argv[2]
    with open(managed_path, "rb") as f:
        managed = tomllib.load(f)
    existing = {}
    if os.path.exists(cfg_path):
        with open(cfg_path, "rb") as f:
            existing = tomllib.load(f)

    # Managed keys win at the top level (mcp_servers is wholly Nix's, the
    # same deal as Claude's .mcpServers), everything else Codex or the user
    # wrote is kept as-is.
    merged = {**existing, **managed}

    tmp = cfg_path + ".tmp"
    with open(tmp, "wb") as f:
        tomli_w.dump(merged, f)
    os.replace(tmp, cfg_path)
  '';
in {
  home.packages = [
    pkgs.nodejs
    rust-mcp-server
    rust-analyzer-mcp
  ];

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

  # Keep config.toml writable; Codex stores project trust alongside MCP settings.
  programs.codex.enable = true;

  home.activation.setupCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CODEX_CONFIG="$HOME/.codex/config.toml"
    mkdir -p "$HOME/.codex"
    # A previous generation managed this as a store symlink; a symlink would
    # also make the tmp-file rename in the merge script land in the store.
    [ -L "$CODEX_CONFIG" ] && rm "$CODEX_CONFIG"
    ${codexMergePython}/bin/python3 ${codexMergeScript} \
      ${codexManagedConfig} "$CODEX_CONFIG"
  '';

  # MCP servers — merged into ~/.claude.json (preserves dynamic state)
  home.activation.setupClaudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_JSON="$HOME/.claude.json"

    if [ -f "$CLAUDE_JSON" ]; then
      ${pkgs.jq}/bin/jq --slurpfile mcp ${mcpConfigFile} \
        '.mcpServers = $mcp[0]' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
        && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
    else
      ${pkgs.jq}/bin/jq -n --slurpfile mcp ${mcpConfigFile} \
        '{mcpServers: $mcp[0]}' > "$CLAUDE_JSON"
    fi
  '';
}
