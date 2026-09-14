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

    # Track newer coding CLIs independently of the system package pin.
    nixpkgs-cli.url = "github:NixOS/nixpkgs/master";
  };

  outputs = { nixpkgs, home-manager, nix-darwin, nvim, fenix, nixpkgs-cli, ... }:
    let
      system = "x86_64-linux";
      cliOverlay = _: prev:
        # Imported rather than taken from legacyPackages so the unfree
        # allowance below applies — claude-code is unfree.
        let fresh = import nixpkgs-cli {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
            };
        in { inherit (fresh) codex claude-code; };

      sharedModule = {
        _module.args = { inherit nvim; };
        nixpkgs.overlays = [ fenix.overlays.default cliOverlay ];
      };
      mkNixos = host: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          (./machines + "/${host}/configuration.nix")
          home-manager.nixosModules.home-manager
          sharedModule
        ];
      };
    in {
      nixosConfigurations = {
        nixos = mkNixos "nixos";
        desktop = mkNixos "desktop";
      };

      # Mac configuration (Apple Silicon)
      #   darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          ./machines/mac/configuration.nix
          home-manager.darwinModules.home-manager
          sharedModule
        ];
      };
    };
}
