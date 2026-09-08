{
  description = "LucidLuckylee's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # macOS system configuration (the M4 Mac shares home/shared.nix)
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim configuration from GitHub
    nvim.url = "github:lucidLuckylee/leon";

    # Rust toolchain manager (replaces rustup on NixOS)
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    # Fresher nixpkgs for the coding CLIs only — codex and claude-code both
    # move faster than the main pin. Tracks master because nixos-unstable
    # lags them by days. Drop this (and the overlay below) whenever the main
    # nixpkgs is updated past what it provides.
    nixpkgs-cli.url = "github:NixOS/nixpkgs/master";
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, nvim, fenix, nixpkgs-cli, ... }:
    let
      system = "x86_64-linux";
      cliOverlay = final: prev:
        # Imported rather than taken from legacyPackages so the unfree
        # allowance below applies — claude-code is unfree.
        let fresh = import nixpkgs-cli {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
            };
        in {
          codex = fresh.codex;
          claude-code = fresh.claude-code;
        };
    in {
      # Laptop configuration
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/nixos/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default cliOverlay ]; }
        ];
      };

      # Desktop configuration
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default cliOverlay ]; }
        ];
      };

      # Mac configuration (Apple Silicon)
      #   darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          ./machines/mac/configuration.nix
          home-manager.darwinModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default cliOverlay ]; }
        ];
      };
    };
}
