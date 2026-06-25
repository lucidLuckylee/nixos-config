{ config, pkgs, ... }:

let
  theme = import ./colors.nix;
  colors = theme.colors;
  opacity = theme.opacity;
  opacity_alpha_hex = theme.opacity_alpha_hex;
  mod = "Mod4";

  # Stable Rust toolchain assembled from fenix components
  rustToolchain = pkgs.fenix.combine (with pkgs.fenix.stable; [
    cargo
    rustc
    rustfmt
    clippy
    rust-src
    rust-analyzer
  ]);
in {
  imports = [
    ./mcp.nix
    ./telegram-claude.nix
  ];

  home.stateVersion = "25.05";

  # Symlink ~/Usb to USB mount location
  home.file."Usb".source = config.lib.file.mkOutOfStoreSymlink "/run/media/lucy";

  home.packages = with pkgs; [
    htop
    bluez
    firefox
    nerd-fonts.dejavu-sans-mono
    ripgrep
    gcc
    rustToolchain
    telegram-desktop
    texlive.combined.scheme-full
    devenv
    ffmpeg
    discord
    claude-code
    jq
    tmux
    swayidle
    gh
    python3
    blesh
    wl-clipboard
    unzip
    remmina
    wakeonlan
    pass                # password-store
    pinentry-curses     # GPG passphrase entry
    pv
    sox                          # Voice chat for claude-code
    playwright-driver.browsers   # Patched Chromium/Firefox/WebKit for Playwright on NixOS
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    NIX_BUILD_SHELL = "bash";
    # Point Playwright at Nix-managed browsers; suppress its self-download
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  # Programs
  programs.bash = {
    enable = true;
    shellAliases = {
      update = "sudo nixos-rebuild switch --flake /home/lucy/NixOS";
      cleanup = "sudo nix-collect-garbage -d; sudo nixos-rebuild boot --flake /home/lucy/NixOS";
      wake-mac = "wakeonlan 1c:f6:4c:45:3a:91";
      clone = "( { output=$(alacritty 2>&1) || echo '$output'; } & disown)";
    };
    bashrcExtra = ''
      # Only configure ble.sh in interactive shells
      if [[ $- == *i* ]]; then
        # Load blesh
        source -- "$(blesh-share)"/ble.sh --attach=none

        bleopt complete_auto_delay=0
        bleopt exec_errexit_mark=
        bleopt exec_elapsed_mark=
        bleopt prompt_eol_mark=
        bleopt keymap_vi_mode_show:=

        # Styling - foreground only, no backgrounds
        ble-face -s auto_complete fg=244
        ble-face -s syntax_default none
        ble-face -s syntax_command fg=green
        ble-face -s syntax_quoted fg=yellow
        ble-face -s syntax_quotation fg=yellow
        ble-face -s syntax_expr fg=cyan
        ble-face -s syntax_error fg=red
        ble-face -s syntax_varname fg=cyan
        ble-face -s syntax_delimiter none
        ble-face -s syntax_param_expansion fg=cyan
        ble-face -s syntax_history_expansion fg=cyan
        ble-face -s syntax_function_name fg=green
        ble-face -s syntax_comment fg=244
        ble-face -s syntax_glob fg=magenta
        ble-face -s syntax_brace fg=magenta
        ble-face -s syntax_tilde fg=cyan
        ble-face -s syntax_document fg=yellow
        ble-face -s syntax_document_begin fg=yellow
        ble-face -s region fg=white,underline
        ble-face -s region_target fg=white,underline
        ble-face -s region_match fg=white,underline
        ble-face -s disabled fg=242
        ble-face -s overwrite_mode fg=red
        ble-face -s vbell none
        ble-face -s vbell_erase none
        ble-face -s vbell_flash none

        # Vi mode settings
        set -o vi
        ble-bind -m auto_complete -f 'C-@' auto_complete/insert

        # Cursor styles: underline for normal, beam for insert (no blinking)
        ble-bind -m vi_nmap --cursor 4   # steady underline
        ble-bind -m vi_imap --cursor 6   # steady beam
        ble-bind -m vi_omap --cursor 4   # steady underline
        ble-bind -m vi_xmap --cursor 4   # steady underline
        ble-bind -m vi_smap --cursor 4   # steady underline

        # System clipboard integration (Wayland) via + register
        # Hook into vi register system for + (code 43) and * (code 42)
        blehook/eval-after-load keymap_vi '
          # Override to intercept + and * registers
          function ble/keymap:vi/register#set {
            local reg=$1 type=$2 content=$3
            # Sync to system clipboard for + (43) and * (42) registers
            if [[ $reg == 43 || $reg == 42 ]]; then
              { wl-copy -- "$content" 2>/dev/null & disown; } 2>/dev/null
            fi
            # Store in register array
            _ble_keymap_vi_register["$reg"]=$type/$content
          }

          # Override to read from clipboard for + and * registers
          function ble/keymap:vi/register#load {
            local reg=$1
            if [[ $reg == 43 || $reg == 42 ]]; then
              local content
              content=$(wl-paste --no-newline 2>/dev/null)
              if [[ $content ]]; then
                ble-edit/content/push-kill-ring "$content" ""
                return 0
              fi
            fi
            # Fall back to original behavior for other registers
            [[ ''${_ble_keymap_vi_register[$reg]+set} ]] || return 1
            local value=''${_ble_keymap_vi_register[$reg]}
            ble-edit/content/push-kill-ring "''${value#*/}" "''${value%%/*}"
            return 0
          }
        '

        # Reduce escape key timeout for faster mode switching
        stty time 0
        bind 'set keyseq-timeout 1'

        # Truncate directory to last 3 components
        PROMPT_DIRTRIM=3

        # Custom directory display function
        function ble/prompt/backslash:short-dir {
          local dir="$PWD"
          # Replace home with ~
          dir="''${dir/#$HOME/\~}"
          # If still too long (>30 chars), truncate from left
          if ((''${#dir} > 30)); then
            dir="…''${dir: -29}"
          fi
          ble/prompt/print "$dir"
        }

        # Dev shell indicator
        function ble/prompt/backslash:nix-shell {
          if [[ -n "$IN_NIX_SHELL" || -n "$DEVENV_ROOT" ]]; then
            ble/prompt/print $'\e[36m[dev]\e[0m '
          fi
        }

        # Custom vi mode indicator function
        function ble/prompt/backslash:vim-mode {
          bleopt keymap_vi_mode_update_prompt:=1
          case $_ble_decode_keymap in
            (vi_imap) ble/prompt/print $'\e[32m❯\e[0m ' ;;
            (*)       ble/prompt/print $'\e[35m❯\e[0m ' ;;
          esac
        }

        # Format elapsed time for right prompt
        function ble/prompt/backslash:elapsed {
          local ms=$_ble_exec_time_tot
          ((ms > 0)) || return 0
          if ((ms < 1000)); then
            ble/prompt/print "''${ms}ms"
          elif ((ms < 60000)); then
            ble/prompt/print "$((ms/1000)).$((ms%1000/100))s"
          else
            ble/prompt/print "$((ms/60000))m$((ms%60000/1000))s"
          fi
        }

        # Use the custom mode indicator in prompt
        PS1='\q{nix-shell}\e[34m\q{short-dir}\e[0m \q{vim-mode}'

        # Right prompt with elapsed time
        bleopt prompt_rps1='\e[90m\q{elapsed}\e[0m'

        # Attach blesh
        ble-attach
      fi
    '';
  };

  # Desktop Environment (Alacritty, Sway, etc....)
  programs.alacritty = {
    enable = true;

    settings = {
      terminal.shell = "${pkgs.bash}/bin/bash";
      font = {
        normal = {
          family = "DejaVu Sans Mono";
          style = "Regular";
        };
        size = 12.0;
      };

      window = {
        decorations = "full";
        opacity = opacity;
      };

      colors = {
        primary = {
          background = colors.background;
          foreground = colors.foreground;
        };
        normal = colors.normal;
        bright = colors.bright;
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "ZeroSync" = {
        hostname = "168.119.139.152";
        user = "root";
      };
      "Mac" = {
        hostname = "192.168.1.190";
        user = "lee";
        extraOptions.RequestTTY = "yes";
      };
    };
  };

  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;      # Cache passphrase for 1 hour
    maxCacheTtl = 86400;         # Max 24 hours
    pinentry.package = pkgs.pinentry-curses;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "lucidLuckylee";
      user.email = "48297887+lucidLuckylee@users.noreply.github.com";
      core.editor = "nvim";
      color.ui = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.default = "current";
      merge.conflictStyle = "diff3";
      credential.helper = "cache";
      credential.cachetimeout = 900;
    };
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
      output = let wp = ./wallpaper.jpg; in {
        "*" = {
          bg = "${wp} fill";
        };
        "DP-1" = {
          mode = "1920x1080@144.001Hz";
          pos = "1680 0";
        };
        "DVI-D-1" = {
          mode = "1680x1050@120Hz";
          pos = "0 0";
        };
      };
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
