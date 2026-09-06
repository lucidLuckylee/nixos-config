{ config, pkgs, ... }:

# Linux/NixOS-only home-manager configuration: the Wayland session, systemd
# user services, and packages that only make sense under Sway.
#
# Cross-platform configuration lives in ./shared.nix.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;
  opacity = theme.opacity;
  opacity_alpha_hex = theme.opacity_alpha_hex;
  workspaces = import ./workspaces.nix;
  mod = "Mod4";

  # wmenu takes colours as bare RRGGBB[AA], with no leading '#'.
  hex = pkgs.lib.removePrefix "#";

  # The animated wallpaper deliberately lives outside the flake. It is a large
  # binary that would bloat every clone, and it composites third-party footage
  # whose licence permits derivative works but not redistribution of the source.
  # Machines that do not have the file simply keep the still — see the
  # ConditionPathExists on the service below.
  animatedWallpaper = "${config.xdg.dataHome}/wallpaper/animated.mp4";

  # Blank the screens on demand, and keep them blank.
  #
  # `swaymsg "output * power off"` on its own does not survive contact with
  # swayidle: the manual blank leaves the session idle, so ten minutes later the
  # idle timeout fires (a no-op, the outputs are already off) and arms its
  # resumeCommand — and the next twitch of the mouse powers the screens back on,
  # without the toggle key ever having been pressed. So swayidle is stopped for
  # as long as the blank lasts. Nothing is lost by that: the only thing swayidle
  # does here is blank the screens, which is already the state we are in.
  #
  # The flag file records whether swayidle was actually running when we blanked,
  # so unblanking restores what was there rather than unconditionally starting
  # it — otherwise this key would silently cancel the "always-on" mode below.
  #
  # `.power` is the field sway 1.9+ reports; `.dpms` is its older name, kept for
  # the case of an older sway on some other machine.
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
    ./telegram-claude.nix
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
    clone = "( { output=$(ghostty 2>&1) || echo '$output'; } & disown)";
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;      # Cache passphrase for 1 hour
    maxCacheTtl = 86400;         # Max 24 hours
    pinentry.package = pkgs.pinentry-curses;
  };

  # i3status is gone with swaybar: the same four readouts — wifi, volume, free
  # disk, the clock — are on the Quickshell bar (./quickshell.nix), read from
  # NetworkManager, PipeWire and the system clock over their own interfaces
  # rather than re-rendered into a status line once a second.

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
  # video is that same still, so the handover is invisible.
  #
  # ConditionPathExists is what makes this safe to define for every Linux
  # machine: where the video is absent the unit is skipped rather than failed,
  # and the still wallpaper is simply what stays on screen. The same holds if
  # mpvpaper dies — the background underneath it is already correct.
  #
  # -p pauses decoding whenever sway stops sending frame callbacks, which covers
  # both a fullscreen window in the way and the screens being powered off by
  # swayidle. Measured: with the outputs off, mpvpaper drops to 0.5% of a core
  # and the GPU to ~10% busy, so the idle blank costs nothing extra.
  #
  # What it deliberately does not cover is an ordinary tiled window, and that is
  # right here rather than a shortcoming: with the `opacity 0.9` rule further
  # down the wallpaper is genuinely still being looked at through every window,
  # so pausing then would show up as a background that stops moving.
  #
  # --really-quiet is there for the journal rather than for power. mpv writes a
  # progress line to stdout twice a second, and systemd faithfully commits all
  # of it to disk: 16k lines of "V: 00:01:02 / 00:04:48" per boot.
  #
  # ── Why the layer is set explicitly ─────────────────────────────────
  # swaybg (spawned by sway from `output.bg` below) and mpvpaper are both
  # layer-shell clients, and left to itself mpvpaper takes the same `background`
  # layer swaybg is on. Two surfaces on one layer are stacked in the order they
  # were created, so whichever started *last* is on top — and sway respawns
  # swaybg every time its config is reloaded, which is every `nixos-rebuild
  # switch`. The video would then silently disappear behind the still until the
  # next reboot, with both processes still running and nothing in either log.
  # mpvpaper says as much on startup: "swaybg is running. This may block
  # mpvpaper from being seen."
  #
  # `bottom` is the layer between `background` and ordinary windows, so the
  # video is unconditionally above the still and unconditionally below
  # everything else. Start order stops mattering.
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

          # Toggle always-on mode
          "${mod}+Shift+m" = ''exec systemctl --user stop swayidle.service; mode "always-on"'';
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
      # No swaybar. The bar is Quickshell's now (./quickshell.nix), which is
      # what makes the Bluetooth menu possible: swaybar's protocol is a line of
      # text and a click event, and nothing in it can open a panel.
      #
      # Left empty rather than deleted so this stays the place someone looks
      # for the bar. The workspace chips, the status readouts and the neon on
      # the focused workspace all moved over; the one thing that did not is the
      # tray, which was already off here (`trayOutput = "none"`).
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

      # mkOptionDefault so this merges with home-manager's default modes rather
      # than replacing them — a plain assignment here drops the built-in
      # "resize" mode, leaving mod+r (still bound above) to enter a mode with no
      # bindings at all, not even Escape back to default.
      modes = pkgs.lib.mkOptionDefault {
        "always-on" = {
          "${mod}+Shift+m" = ''exec systemctl --user start swayidle.service; mode "default"'';
        };
      };
    };
  };
}
