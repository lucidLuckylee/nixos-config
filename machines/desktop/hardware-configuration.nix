# TODO: This is a placeholder file!
#
# When you're on your desktop machine, generate the actual hardware configuration using:
#   sudo nixos-generate-config --show-hardware-config > /home/lucy/NixOS/machines/desktop/hardware-configuration.nix
#
# Then commit and push the changes to the repository.

{ config, lib, pkgs, modulesPath, ... }:

{
  # Placeholder configuration - replace with actual hardware config
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # This will need to be replaced with actual filesystem configuration
  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/REPLACE-WITH-ACTUAL-UUID";
  #   fsType = "ext4";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
