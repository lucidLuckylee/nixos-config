{ config, pkgs, nvim, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
    ../../modules/sway.nix
  ];

  # Hostname
  networking.hostName = "desktop";

  # Desktop-specific hardware (add as needed)
  # hardware.bluetooth.enable = true;

  # Home Manager configuration
  home-manager.backupFileExtension = "backup";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.lucy = {
    imports = [ ../../home/desktop.nix ];
  };
}
