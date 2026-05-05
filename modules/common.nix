{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "lucy" ];

  # Read-only access to nix-community's binary cache (fenix toolchains, etc.)
  nix.settings.substituters = [ "https://nix-community.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Bootloader (UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel parameters
  boot.kernelParams = [ "tsc=reliable" ];

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

  programs.bash.enable = true;

  # Create /bin/bash symlink for shebang compatibility
  system.activationScripts.binbash = ''
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Podman container support
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # QEMU/KVM for quickemu (macOS VMs, etc.)
  virtualisation.libvirtd.enable = true;
  environment.systemPackages = with pkgs; [
    quickemu
    libvirt
    virt-manager
    pciutils
  ];


  # ── Gaming ──────────────────────────────────────────────────────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # 32-bit Vulkan/OpenGL for Steam games
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.gamemode.enable = true;  # Feral GameMode – optimizes CPU/GPU on demand

  # USB auto-mounting
  services.udisks2.enable = true;

  environment.etc."distrobox/distrobox.conf".text = ''
    container_additional_volumes="/nix/store:/nix/store:ro
    /etc/profiles/per-user:/etc/profiles/per-user:ro"
  '';

  environment.variables = {
  };

  system.stateVersion = "25.05";
}
