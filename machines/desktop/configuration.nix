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
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;  # Proprietary driver (required for GTX 1080)
  };

  # ── WIFI CARD FENVI AX900 + BT5.4 ─────────────────────────────────
  hardware.enableRedistributableFirmware = true;

# Home Manager configuration
  home-manager.backupFileExtension = "backup";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.lucy = {
    imports = [ ../../home/desktop.nix ];
  };
}
