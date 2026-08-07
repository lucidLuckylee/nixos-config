{ config, pkgs, ... }:

# macOS-only home-manager configuration.
#
# Cross-platform configuration lives in ./shared.nix. GUI applications are
# installed as Homebrew casks from ../machines/mac/configuration.nix rather than
# through Nix — Nix-installed .app bundles don't register with Spotlight or
# Launchpad without extra tooling, and the casks were already in use here.

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

  # Locale. NixOS gets this from i18n.defaultLocale / i18n.extraLocaleSettings
  # in modules/common.nix; nix-darwin has no equivalent, so LANG was simply
  # unset here and ble.sh complained about it. Both locales below ship with
  # macOS (confirmed via `locale -a`), so no glibc locale archive is needed.
  # Values mirror the NixOS side: English messages, German formatting.
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

  # home-manager takes ownership of ~/.bashrc, which until now was where the
  # Homebrew and ~/.local/bin PATH entries were set (the previous file is kept
  # as ~/.bashrc.backup). Re-add them here so brew and the tools installed
  # through it keep working — appended rather than prepended, so Nix's versions
  # of anything present in both still win.
  #
  # Deliberately not restored: `. "$HOME/.cargo/env"`. The fenix toolchain from
  # shared.nix now provides rustc/cargo, same as on the NixOS hosts. Add
  # $HOME/.cargo/bin below if you still want binaries from `cargo install`.
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
