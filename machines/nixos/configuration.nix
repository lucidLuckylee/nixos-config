{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
    ../../modules/sway.nix
    ../../modules/power.nix
    ../../modules/overlays.nix
  ];

  networking.hostName = "nixos";

  # Laptop-specific hardware
  home-manager.users.lucy.imports = [ ../../home/laptop.nix ];
}
