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

  # ── NVIDIA GPU ────────────────────────────────────────────────────
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;  # Proprietary driver (required for GTX 1080)
  };

  hardware.graphics.enable = true;

  # Home Manager configuration
  home-manager.backupFileExtension = "backup";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.lucy = {
    imports = [ ../../home/desktop.nix ];
  };
}
