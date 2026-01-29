{ config, pkgs, ... }:

let
  theme = import ./colors.nix;
  colors = theme.colors;
  opacity = theme.opacity;
  opacity_alpha_hex = theme.opacity_alpha_hex;
  mod = "Mod4";
in {
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    htop
    bluez
    firefox
    nerd-fonts.dejavu-sans-mono
    ripgrep
    gcc
    rustup
    telegram-desktop
    texlive.combined.scheme-full
    devenv
    ffmpeg
    discord
    code-cursor
    claude-code
    jq
    tmux
    swayidle
    gh
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Programs
  programs.zsh = {
    enable = true;

    shellAliases = {
      update = "sudo nixos-rebuild switch --flake /home/lucy/NixOS";
      cleanup = "sudo nix-collect-garbage -d; sudo nixos-rebuild boot --flake /home/lucy/NixOS";
    };

    plugins = [
      { name = "zsh-autosuggestions"; src = pkgs.zsh-autosuggestions; }
      { name = "zsh-syntax-highlighting"; src = pkgs.zsh-syntax-highlighting; }
    ];
    autosuggestion.enable = true;
    autosuggestion.highlight = "fg=magenta";
    syntaxHighlighting.enable = true;

    initContent = ''
      # Bind to ctrl + space
      bindkey '^ ' autosuggest-accept
    '';
  };

  # Desktop Environment (Alacritty, Sway, etc....)
  programs.alacritty = {
    enable = true;

    settings = {
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

          # Special key to take a screenshot with grim
          "Print" = "exec grim";

          # Toggle always-on mode
          "${mod}+Shift+m" = ''exec systemctl --user stop swayidle.service; mode "always-on"'';
        }
      );
      bars = [{
        position = "top";
        statusCommand = "i3status -c ${config.xdg.configHome}/i3status/config";
        trayOutput = "none";
        colors = {
          background = colors.background + opacity_alpha_hex;
        };
      }];
      window.titlebar = false;
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
