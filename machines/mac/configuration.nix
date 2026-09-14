{ config, pkgs, nvim, ... }:

# M4 Mac configuration. Shared home settings live in ../../home/shared.nix.

{
  imports = [
    ../../modules/overlays.nix
    ./window-manager.nix
    ./keyboard.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "mac";

  # Determinate manages the Nix daemon; disable nix-darwin's competing service.
  nix.enable = false;

  users.users.lee = {
    name = "lee";
    home = "/Users/lee";
  };

  # Which user the system.defaults and activation scripts apply to.
  system.primaryUser = "lee";

  fonts.packages = [ pkgs.nerd-fonts.dejavu-sans-mono ];

  # Léon — the same Neovim configuration the NixOS hosts get from modules/sway.nix
  environment.systemPackages = [
    nvim.packages.aarch64-darwin.default
  ];

  # Home Manager configuration
  home-manager.backupFileExtension = "backup";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.lee = {
    imports = [ ../../home/darwin.nix ];
  };

  # ── macOS behaviour ─────────────────────────────────────────────────
  system.keyboard.enableKeyMapping = true;
  # Caps Lock → Escape is deliberately NOT set here: Karabiner-Elements
  # already does it (along with the Linux-style Ctrl+C/V/X/Z bindings), and
  # having both remap the same key fights.

  system.defaults = {
    NSGlobalDomain = {
      # Match Sway's repeat_delay = 200 / repeat_rate = 60 as closely as the
      # macOS scale allows. Units are 15ms ticks: 15 ≈ 225ms, KeyRepeat 1 is
      # the fastest setting the UI can't even reach.
      InitialKeyRepeat = 15;
      KeyRepeat = 1;

      # Hold-a-key must repeat the character, not open the accent picker.
      # Non-negotiable for vim.
      ApplePressAndHoldEnabled = false;

      # "Natural" scrolling off — matches every non-Apple machine.
      "com.apple.swipescrolldirection" = false;

      AppleShowAllExtensions = true;

      # Stop macOS rewriting what you type. These mangle code in any
      # non-code-aware text field.
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;

      # Ctrl+Cmd+drag moves a window from anywhere in its body, not just the
      # title bar. The closest macOS gets to Sway's $mod+drag.
      NSWindowShouldDragOnGesture = true;

      # No animation on window open/close.
      NSAutomaticWindowAnimationsEnabled = false;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      show-recents = false;
      # Keep Spaces in a fixed order. Without this macOS reorders them by
      # recency, which makes "switch to desktop 3" mean something different
      # every time — the single most confusing default for an i3/Sway user.
      mru-spaces = false;
      tilesize = 40;
      expose-group-apps = true;
      # Disable the hot corners.
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXEnableExtensionChangeWarning = false;
      # Always list view, and sort folders first, like every file manager
      # that isn't Finder.
      FXPreferredViewStyle = "Nlsv";
      _FXSortFoldersFirst = true;
      _FXShowPosixPathInTitle = true;
    };

    trackpad = {
      Clicking = true;              # tap to click — Sway's `tap = enabled`
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
    };

    # Same directory the Sway screenshot bindings write to.
    screencapture.location = "~/Screenshots";
    screencapture.disable-shadow = true;

    # Clicking the wallpaper should not shove every window off-screen.
    WindowManager.EnableStandardClickToShowDesktop = false;

    loginwindow.GuestEnabled = false;
  };

  # Enable Ctrl+1..9 for Spaces manually in Keyboard Shortcuts → Mission Control;
  # these symbolic hotkeys cannot be set reliably through system.defaults.

  # ── Homebrew ────────────────────────────────────────────────────────
  # GUI applications stay on Homebrew; this block just makes the list
  # declarative. Requires Homebrew to already be installed (it is).
  homebrew = {
    enable = true;
    onActivation = {
      # Never uninstall things that aren't listed here — this config does not
      # claim ownership of everything already installed by hand.
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
    # Manage the existing casks; Firefox and Discord are installed separately.
    casks = [
      "alacritty"
      "karabiner-elements"
      "telegram"
    ];
  };

  system.stateVersion = 6;
}
