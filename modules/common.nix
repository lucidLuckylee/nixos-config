{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "lucy" ];

  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Locale and timezone
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Keyboard layout (TTY + X11)
  console.keyMap = "de-latin1-nodeadkeys";
  services.xserver.xkb = {
    layout = "de";
    variant = "nodeadkeys";
    options = "caps:escape";
  };

  programs.zsh.enable = true;

  # Podman container support
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # QEMU/KVM for quickemu (macOS VMs, etc.)
  virtualisation.libvirtd.enable = true;
  environment.systemPackages = with pkgs; [
    quickemu
  ];

  environment.etc."distrobox/distrobox.conf".text = ''
    container_additional_volumes="/nix/store:/nix/store:ro
    /etc/profiles/per-user:/etc/profiles/per-user:ro"
  '';

  environment.variables = {
    NIX_BUILD_SHELL = "${pkgs.zsh}/bin/zsh";
  };

  system.stateVersion = "25.05";
}
