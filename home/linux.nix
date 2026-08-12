{ config, pkgs, ... }:

# Linux/NixOS-only home-manager configuration: the Wayland session, systemd
# user services, and packages that only make sense under Sway.
#
# Cross-platform configuration lives in ./shared.nix.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  opacity = theme.opacity;
  opacity_alpha_hex = theme.opacity_alpha_hex;
  mod = "Mod4";
in {
  imports = [
    ./telegram-claude.nix
  ];

  # Symlink ~/Usb to USB mount location
  home.file."Usb".source = config.lib.file.mkOutOfStoreSymlink "/run/media/lucy";

  home.packages = with pkgs; [
    bluez
    firefox
    gcc
    telegram-desktop
    discord
    swayidle
    wl-clipboard
    remmina
    gowall              # Recolour images/wallpapers to a palette
    mpvpaper            # Animated wallpaper (see systemd.user.services below)
    vscode

    # Deliberately not in ./shared.nix — these are the heavy packages the Mac
    # was carrying without using, 8.8 GB of closure between them:
    #   texliveFull  6.83 GB   documents are written on the NixOS machines
    #   python3      1.45 GB   macOS ships /usr/bin/python3, and uv can fetch
    #                          its own interpreters when a newer one is needed
    #   devenv       0.52 GB   per-project dev shells are a NixOS workflow here
    # The top-level scheme, not texlive.combined.scheme-full — the combined.*
    # attributes are deprecated and go away in nixpkgs 27.05.
    texliveFull
    python3
    devenv
  ];

  fonts.fontconfig.enable = true;

  programs.bash.shellAliases = {
    update = "sudo nixos-rebuild switch --flake /home/lucy/NixOS";
    cleanup = "sudo nix-collect-garbage -d; sudo nixos-rebuild boot --flake /home/lucy/NixOS";
    wake-mac = "wakeonlan 1c:f6:4c:45:3a:91";
    clone = "( { output=$(alacritty 2>&1) || echo '$output'; } & disown)";
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;      # Cache passphrase for 1 hour
    maxCacheTtl = 86400;         # Max 24 hours
    pinentry.package = pkgs.pinentry-curses;
  };

  programs.i3status = {
    enable = true;
    enableDefault = false;
    general = {
      colors = true;
      color_good = colors.foreground;
      color_degraded = colors.normal.yellow;
      color_bad = colors.normal.red;
      interval = 1;
    };
    modules = {
    "wireless _first_" = {
      position = 0;
      settings = {
        color_good = colors.normal.green;
        format_up = "%essid%quality %bitrate 󱚽 ";
        format_down = "󰖪 ";
        format_bitrate = "%g%cb/s";
      };
    };
      "volume master" = {
        position = 1;
        settings = {
          format = "󰎇  %volume ";
          format_muted = "󰎊 (%volume)";
        };
      };
      "disk /" = {
        position = 2;
        settings = {
          format = " %avail";
        };
      };
      "time" = {
        position = 4;
        settings = {
          format = "%d.%m. %H:%M";
        };
      };
    };
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

  # Animated wallpaper.
  #
  # swaybg can only draw a still, so the sway config below keeps ./wallpaper.jpg
  # as the background and mpvpaper layers the video over it. Frame 0 of the
  # video is that same still, so the handover is invisible — and if this service
  # ever fails to start, what is left on screen is the correct wallpaper rather
  # than a black screen.
  #
  # -p pauses decoding whenever the wallpaper is fully covered, which is most of
  # the time in practice. Running uncovered it costs ~5% of one core.
  systemd.user.services.mpvpaper = {
    Unit = {
      Description = "Animated wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = pkgs.lib.concatStringsSep " " [
        "${pkgs.mpvpaper}/bin/mpvpaper"
        "-p"
        "-o '--loop-file=inf --no-audio --hwdec=auto --video-unscaled=no'"
        "'*'"
        "${./wallpaper-anim.mp4}"
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
      terminal = "alacritty";
      menu = "wmenu-run";
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
        // {
          "${mod}+t" = "workspace ";
          "${mod}+Shift+t" = "move container to workspace ; workspace ";
          "${mod}+Shift+o" = "floating toggle";
          "${mod}+o" = "focus mode_toggle";

          "${mod}+space" = "workspace ";
          "${mod}+Shift+space" = "move container to workspace ; workspace ";
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

          # Toggle always-on mode
          "${mod}+Shift+m" = ''exec systemctl --user stop swayidle.service; mode "always-on"'';
        }
      );
      colors = {
        background = colors.background;
        focused = {
          border      = colors.bright.red;
          background  = colors.normal.black;
          text        = colors.bright.white;
          indicator   = colors.bright.white;
          childBorder = colors.bright.red;
        };
        focusedInactive = {
          border      = colors.normal.black;
          background  = colors.normal.black;
          text        = colors.bright.white;
          indicator   = colors.normal.black;
          childBorder = colors.normal.black;
        };
        unfocused = {
          border      = colors.normal.black;
          background  = colors.normal.black;
          text        = colors.foreground;
          indicator   = colors.normal.black;
          childBorder = colors.normal.black;
        };
        urgent = {
          border      = colors.bright.yellow;
          background  = colors.bright.yellow;
          text        = colors.normal.black;
          indicator   = colors.bright.yellow;
          childBorder = colors.bright.yellow;
        };
        placeholder = {
          border      = colors.bright.black;
          background  = colors.bright.black;
          text        = colors.bright.white;
          indicator   = colors.bright.black;
          childBorder = colors.bright.black;
        };
      };
      bars = [{
        position = "top";
        statusCommand = "i3status -c ${config.xdg.configHome}/i3status/config";
        trayOutput = "none";
        colors = {
          background = colors.background + opacity_alpha_hex;
          statusline = colors.bright.white;
          separator  = colors.normal.red;
          focusedWorkspace = {
            border     = colors.bright.red;
            background = colors.bright.red;
            text       = colors.bright.white;
          };
          activeWorkspace = {
            border     = colors.normal.red;
            background = colors.normal.black;
            text       = colors.bright.white;
          };
          inactiveWorkspace = {
            border     = colors.background;
            background = colors.background;
            text       = colors.foreground;
          };
          urgentWorkspace = {
            border     = colors.bright.yellow;
            background = colors.bright.yellow;
            text       = colors.normal.black;
          };
        };
      }];
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

      modes = {
        "always-on" = {
          "${mod}+Shift+m" = ''exec systemctl --user start swayidle.service; mode "default"'';
        };
      };
    };
  };
}
