{ config, pkgs, ... }:

# Linux home configuration: Sway, user services and platform-specific packages.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent opacity opacity_alpha_hex;
  workspaces = import ./workspaces.nix;
  alwaysOn = import ./always-on.nix { inherit pkgs; };
  mod = "Mod4";

  # wmenu takes colours as bare RRGGBB[AA], with no leading '#'.
  hex = pkgs.lib.removePrefix "#";

  # Keep the large video outside the flake. The service skips it when absent.
  animatedWallpaper = "${config.xdg.dataHome}/wallpaper/animated.mp4";

  # Pause swayidle while manually blanked, then restore its previous state.
  # This prevents mouse motion from undoing blanking or cancelling always-on.
  # The .dpms fallback supports older Sway versions.
  blankToggle = pkgs.writeShellScript "sway-blank-toggle" ''
    set -eu
    flag="''${XDG_RUNTIME_DIR:-/tmp}/sway-blank.swayidle-was-active"

    on=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r \
      | ${pkgs.jq}/bin/jq -r 'any(.[]; (.power // .dpms) == true)')

    if [ "$on" = "true" ]; then
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet swayidle.service; then
        : > "$flag"
        ${pkgs.systemd}/bin/systemctl --user stop swayidle.service
      else
        rm -f "$flag"
      fi
      ${pkgs.sway}/bin/swaymsg "output * power off"
    else
      ${pkgs.sway}/bin/swaymsg "output * power on"
      if [ -e "$flag" ]; then
        rm -f "$flag"
        ${pkgs.systemd}/bin/systemctl --user start swayidle.service
      fi
    fi
  '';
in {
  imports = [
    ./firefox.nix
    ./telegram-theme.nix
    ./gtk.nix
    ./tg.nix
    ./quickshell.nix
  ];

  # Symlink ~/Usb to USB mount location
  home.file."Usb".source = config.lib.file.mkOutOfStoreSymlink "/run/media/lucy";

  home.packages = with pkgs; [
    bluez
    gcc
    telegram-desktop
    discord
    swayidle
    wl-clipboard
    remmina
    gowall              # Recolour images/wallpapers to a palette
    mpvpaper            # Animated wallpaper (see systemd.user.services below)
    vscode

    # Large development packages used only on the Linux hosts.
    texliveFull
    python3
    devenv
  ];

  fonts.fontconfig.enable = true;

  programs.bash.shellAliases = {
    update = "sudo nixos-rebuild switch --flake /home/lucy/NixOS";
    cleanup = "sudo nix-collect-garbage -d; sudo nixos-rebuild boot --flake /home/lucy/NixOS";
    wake-mac = "wakeonlan 1c:f6:4c:45:3a:91";
    clone = "( { output=$(ghostty 2>&1) || echo '$output'; } & disown)";
  };

  # The GPG key keeps its own passphrase. A graphical pinentry lets the bar's
  # agenda sync ask for it, and every use restarts the hour, so the key stays
  # unlocked while the bar polls; a week bounds it.
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 604800;
    pinentry.package = pkgs.pinentry-qt;
  };

  # Keep the pass store current; the activation hook in pass.nix clones it.
  systemd.user.services.pass-store-sync = {
    Unit.Description = "Pull the pass store";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/pass-store-sync";
    };
  };
  systemd.user.timers.pass-store-sync = {
    Unit.Description = "Pull the pass store hourly";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };


  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = ''${pkgs.sway}/bin/swaymsg "output * power off"'';
        resumeCommand = ''${pkgs.sway}/bin/swaymsg "output * power on"'';
      }
    ];
  };

  # Keep the still wallpaper underneath as a fallback. The bottom layer stays
  # above swaybg across reloads; -p pauses decoding when frame callbacks stop.
  systemd.user.services.mpvpaper = {
    Unit = {
      Description = "Animated wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionPathExists = animatedWallpaper;
    };
    Service = {
      ExecStart = pkgs.lib.concatStringsSep " " [
        "${pkgs.mpvpaper}/bin/mpvpaper"
        "-p"
        "-l bottom"
        "-o '--loop-file=inf --no-audio --hwdec=auto --video-unscaled=no --really-quiet'"
        "'*'"
        animatedWallpaper
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # USB auto-mounting
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never";  # No tray icon in Sway bar
  };

  # Sway configuration
  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = mod;
      terminal = "ghostty";
      menu = pkgs.lib.concatStringsSep " " [
        "wmenu-run"
        "-N ${hex colors.background}${opacity_alpha_hex}"
        "-n ${hex colors.foreground}"
        "-M ${hex accent.surface}"
        "-m ${hex accent.primary}"
        "-S ${hex accent.primary}"
        "-s ${hex colors.background}"
      ];
      input = {
        "*" = {
          dwt = "enabled";
          tap = "enabled";

          xkb_layout = "de";
          xkb_variant = "nodeadkeys";
          xkb_options = "caps:escape";
          repeat_delay = "200";
          repeat_rate = "60";
          xkb_model = "pc104";
        };
      };
      output."*".bg = "${./wallpaper.jpg} fill";
      workspaceAutoBackAndForth = true;
      focus = {
        wrapping = "yes";
      };
      keybindings = pkgs.lib.mkOptionDefault (
        builtins.listToAttrs (map (i: {
          name = "${mod}+Shift+${toString i}";
          value = "move container to workspace number ${toString i}; workspace number ${toString i}";
        }) [1 2 3 4 5 6 7 8 9] )
        # The named workspaces — Firefox and Telegram — come from
        # ./workspaces.nix, so their glyphs are written down once instead of
        # four times here and once more in the bar's ordering.
        // builtins.listToAttrs (builtins.concatMap (ws: [
          { name = "${mod}+${ws.key}"; value = "workspace ${ws.name}"; }
          { name = "${mod}+Shift+${ws.key}";
            value = "move container to workspace ${ws.name}; workspace ${ws.name}"; }
        ]) workspaces.named)
        // {
          "${mod}+Shift+o" = "floating toggle";
          "${mod}+o" = "focus mode_toggle";

          "${mod}+Shift+tab" = "move scratchpad";
          "${mod}+tab" = "scratchpad show";

          "--locked XF86AudioMute" = "exec pactl set-sink-mute \@DEFAULT_SINK@ toggle";
          "--locked XF86AudioLowerVolume" = "exec pactl set-sink-volume \@DEFAULT_SINK@ -5%";
          "--locked XF86AudioRaiseVolume" = "exec pactl set-sink-volume \@DEFAULT_SINK@ +5%";
          "--locked XF86AudioMicMute" = "exec pactl set-source-mute \@DEFAULT_SOURCE@ toggle";

          # Screenshot: Print = select region, Shift+Print = focused window (also copies to clipboard)
          "Print" = ''exec sh -c 'mkdir -p ~/Screenshots && f=~/Screenshots/region_$(date +%Y-%m-%d_%H-%M-%S).png && grim -g "$(slurp)" "$f" && wl-copy < "$f"' '';
          "Shift+Print" = ''exec sh -c 'mkdir -p ~/Screenshots && win=$(swaymsg -t get_tree | jq -r ".. | select(.focused?) | .app_id // .name // \"window\"" | tr -cs "[:alnum:]-_" "_" | head -c 30) && geo=$(swaymsg -t get_tree | jq -r ".. | select(.focused?) | .rect | \"\(.x),\(.y) \(.width)x\(.height)\"") && f=~/Screenshots/''${win}_$(date +%Y-%m-%d_%H-%M-%S).png && grim -g "$geo" "$f" && wl-copy < "$f"' '';

          # Move entire workspace to the other monitor (cycles through outputs)
          "${mod}+Shift+w" = ''exec swaymsg -t get_outputs | jq '[.[] | select(.active == true)] | .[(map(.focused) | index(true) + 1) % length].name' | xargs swaymsg move workspace to'';

          # Turn the screens off until the same chord is pressed again.
          # --locked so the second press gets through a lock screen, and
          # --no-repeat so holding the key does not blank-unblank in a loop.
          "--locked --no-repeat ${mod}+XF86MonBrightnessDown" = "exec ${blankToggle}";

          # Toggle always-on; the bar's coffee pill runs the same script.
          "${mod}+Shift+m" = "exec ${alwaysOn} toggle";
        }
      );
      # Only the focused window gets the neon; everything else recedes into the
      # dim slate so a single cyan edge marks focus across both monitors.
      colors = {
        background = colors.background;
        focused = {
          border      = accent.primary;
          background  = accent.surface;
          text        = colors.bright.white;
          indicator   = accent.primary;
          childBorder = accent.primary;
        };
        focusedInactive = {
          border      = accent.dim;
          background  = accent.surface;
          text        = accent.muted;
          indicator   = accent.dim;
          childBorder = accent.dim;
        };
        unfocused = {
          border      = accent.dim;
          background  = colors.background;
          text        = accent.muted;
          indicator   = accent.dim;
          childBorder = accent.dim;
        };
        urgent = {
          border      = accent.warm;
          background  = accent.warm;
          text        = colors.background;
          indicator   = accent.warm;
          childBorder = accent.warm;
        };
        placeholder = {
          border      = accent.dim;
          background  = accent.surface;
          text        = accent.muted;
          indicator   = accent.dim;
          childBorder = accent.dim;
        };
      };
      # Quickshell supplies the bar.
      bars = [];
      window.titlebar = false;
      window.border = 1;
      window.hideEdgeBorders = "none";
      window.commands = [
        {
          command = "opacity ${toString opacity}";
          criteria = {
            all = "";
          };
        }
      ];
    };
  };
}
