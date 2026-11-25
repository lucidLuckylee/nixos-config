# MCP server definitions for Claude. Activation merges them into a writable
# file so application state survives; Claude's own settings live in agents.nix.
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

  browserDelegate = pkgs.writeShellApplication {
    name = "mac-browser-mcp";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      export MAC_BROWSER_PLAYWRIGHT_COMMAND=${mcpServers.playwright.command}
      exec python3 ${./mac-browser.py}
    '';
  };
in {
  home.packages = [
    pkgs.nodejs
    rust-mcp-server
    rust-analyzer-mcp
  ];

  # Expose one browser task to the coding model, rather than the full catalogue.
  # Decider selects concrete actions in Nix-managed Firefox through Playwright.
  home.file.".config/mac-llm/mcp.json".text = builtins.toJSON {
    mcpServers.browser = {
      command = "${browserDelegate}/bin/mac-browser-mcp";
      args = [];
    };
  };

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
