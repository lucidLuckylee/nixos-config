{
  description = "LucidLuckylee's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Neovim configuration from GitHub
    nvim.url = "github:lucidLuckylee/leon";
  };

  outputs = { self, nixpkgs, home-manager, nvim, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true;};
    in {
      # Laptop configuration
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/nixos/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
        ];
      };

      # Desktop configuration
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          { _module.args = { inherit nvim; }; }
        ];
      };
    };
}
