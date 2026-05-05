# Claude Code settings and MCP (Model Context Protocol) server configuration
#
# Settings (model, permissions, plugins) are managed via ~/.claude/settings.json
# MCP servers are merged into ~/.claude.json via an activation script, since
# that file contains dynamic state that Nix shouldn't fully own.
#
{ pkgs, lib, ... }:
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

  # ── Claude Code global settings (owns ~/.claude/settings.json) ────
  claudeSettings = {
    model = "opus";

    permissions = {
      allow = [
        "WebFetch(domain:github.com)"
        "WebFetch(domain:raw.githubusercontent.com)"
        "WebSearch"
      ];
      defaultMode = "default";
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

    # Bitcoin: key gen, address validation, tx decoding, blockchain queries
    bitcoin = {
      command = npx;
      args = [ "-y" "bitcoin-mcp@latest" ];
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
      args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home/lucy" ];
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
  };

  mcpConfigFile = pkgs.writeText "claude-mcp-servers.json"
    (builtins.toJSON mcpServers);
in {
  home.packages = [
    pkgs.nodejs
    pkgs.uv
    rust-mcp-server
    rust-analyzer-mcp
  ];

  # Static settings — Nix fully owns this file
  home.file.".claude/settings.json".text = builtins.toJSON claudeSettings;

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
