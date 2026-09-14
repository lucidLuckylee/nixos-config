{ config, pkgs, lib, ... }:

# Use BSD stty ahead of GNU coreutils: ble.sh runs `stty sane`, which fails
# with GNU stty on macOS.

# macOS home configuration. GUI apps are managed by Homebrew casks.

{
  imports = [
    ./shared.nix
  ];

  home.username = "lee";
  home.homeDirectory = "/Users/lee";

  home.packages = with pkgs; [
    # GNU userland. macOS ships BSD variants of these (and no `timeout` at
    # all), which is the main source of "this worked on my other machine"
    # friction. Note these do shadow the system versions on PATH.
    coreutils
    findutils
    gnused
    gnugrep
    gnutar
    gawk

    # clang comes from the Xcode toolchain on macOS, so no gcc here.
  ];

  # Ahead of the home-manager profile on PATH, so this stty wins over GNU's.
  # Not in home.packages — that would collide with coreutils in the profile.
  home.sessionPath = [
    "${pkgs.runCommandLocal "bsd-stty" { } ''
      mkdir -p "$out/bin"
      ln -s /bin/stty "$out/bin/stty"
    ''}/bin"
  ];

  # Match the NixOS locale settings; nix-darwin has no i18n module.
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
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

  # Append Homebrew and local tools so Nix packages keep precedence.
  programs.bash.initExtra = ''
    export PATH="$PATH:/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin"
  '';

  programs.bash.shellAliases = {
    update = "sudo darwin-rebuild switch --flake ${config.home.homeDirectory}/nixos-config#mac";
    cleanup = "nix-collect-garbage -d";
    clone = "open -na Alacritty";
  };

  # system.defaults.screencapture.location points here to match the Sway
  # screenshot bindings. macOS silently falls back to the Desktop if the
  # directory doesn't exist, so make sure it does.
  home.file."Screenshots/.keep".text = "";

  # gpg-agent. home-manager's services.gpg-agent module is systemd-based and so
  # unavailable here; the agent auto-starts on first use from this config
  # instead. Cache lifetimes match the NixOS side.
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
    default-cache-ttl 3600
    max-cache-ttl 86400
  '';
}
