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
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, nvim, fenix, ... }:
    let
      system = "x86_64-linux";
    in {
      # Laptop configuration
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/nixos/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default ]; }
        ];
      };

      # Desktop configuration
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default ]; }
        ];
      };

      # Mac configuration (Apple Silicon)
      #   darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          ./machines/mac/configuration.nix
          home-manager.darwinModules.home-manager
          { _module.args = { inherit nvim; }; }
          { nixpkgs.overlays = [ fenix.overlays.default ]; }
        ];
      };
    };
}
