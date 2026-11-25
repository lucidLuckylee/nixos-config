{ pkgs, ... }:

{
  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "lucy" ];

  # Read-only access to nix-community's binary cache (fenix toolchains, etc.)
  nix.settings.substituters = [ "https://nix-community.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Optional GitHub credentials stay outside the store in /etc/nix/access-tokens.conf.
  # Use `access-tokens = github.com=TOKEN`, owned by root:wheel with mode 0640.
  # The !include tolerates a missing file.
  nix.extraOptions = ''
    !include /etc/nix/access-tokens.conf
  '';

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

  environment.systemPackages = with pkgs; [
    pciutils
    pulseaudio  # pactl for the volume keys
  ];

  # Audio through PipeWire; RTKit gives it realtime scheduling.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth for the Quickshell Bluetooth menu.
  hardware.bluetooth.enable = true;


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

  # Expose system and Bluetooth battery state to Quickshell over D-Bus.
  services.upower.enable = true;

  system.stateVersion = "25.05";
}
