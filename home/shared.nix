{ config, pkgs, lib, ... }:

# Cross-platform home configuration. Platform-specific settings live in
# linux.nix and darwin.nix.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent opacity;

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # One opaque dot per transparent tile, using the shared raster pitch.
  inherit (theme) dotGap;
  dotTile = pkgs.runCommand "raster-dot-${toString dotGap}.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    ''
      magick -size ${toString dotGap}x${toString dotGap} xc:none \
        -fill '${accent.primary}' -draw 'point 0,0' PNG32:$out
    '';

  # Embed the accent-coloured tick without depending on an icon-theme lookup.
  copyTick = pkgs.writeText "ghostty-copy-tick.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 20 20">
      <path d="M4.25 10.5 L8.25 14.5 L15.75 6" fill="none" stroke="${accent.primary}"
            stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  '';

  # Linux-only Ghostty toast styling. Use a file:// URL because Ghostty loads
  # the CSS as a string without a base directory.
  ghosttyCss = pkgs.writeText "ghostty.css" ''
    toast {
      /* A disc rather than a pill: the tick is all that is left inside. */
      min-width: 36px;
      min-height: 36px;
      padding: 0;
      margin: 0 0 16px 0;
      border-radius: 999px;

      /* Panel fill so terminal text does not read through it, a neon rim and
         a soft bloom for the signage the palette came from, and a drop shadow
         to lift the whole thing off the raster. */
      background: alpha(${accent.panel}, 0.92);
      box-shadow: 0 0 0 1px alpha(${accent.primary}, 0.45),
                  0 0 14px alpha(${accent.primary}, 0.18),
                  0 4px 12px alpha(black, 0.55);

      background-image: url("file://${copyTick}");
      background-repeat: no-repeat;
      background-position: center;
      background-size: 20px 20px;
    }

    /* Adwaita adds a directional padding that the shorthand above does not
       reach, and it pushes the tick off centre. */
    toast:dir(ltr), toast:dir(rtl) { padding: 0; }

    /* GTK CSS has no `display: none`, so the label and the close button have
       to be shrunk to nothing instead. A transparent 1px label still occupies
       a few pixels, which is why min-width above sets the real size. */
    toast > widget { margin: 0; }
    toast > widget > label { font-size: 1px; color: transparent; }
    toast > button {
      min-width: 0;
      min-height: 0;
      padding: 0;
      margin: 0;
      opacity: 0;
      -gtk-icon-size: 1px;
    }
  '';

  # Stable Rust toolchain assembled from fenix components
  rustToolchain = pkgs.fenix.combine (with pkgs.fenix.stable; [
    cargo
    rustc
    rustfmt
    clippy
    rust-src
    rust-analyzer
  ]);

  # Use each platform's clipboard tools for ble.sh vi-register integration.
  clipCopy = if isDarwin
    then "printf '%s' \"$1\" | /usr/bin/pbcopy"
    else "${pkgs.wl-clipboard}/bin/wl-copy -- \"$1\"";
  clipPaste = if isDarwin
    then "/usr/bin/pbpaste"
    else "${pkgs.wl-clipboard}/bin/wl-paste --no-newline";
in {
  imports = [
    ./mcp.nix
    ./pass.nix
    ./agents.nix
  ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    htop
    ripgrep
    jq
    tmux
    gh
    blesh
    unzip
    wakeonlan
    pinentry-curses     # GPG passphrase entry
    pv
    sox                 # Voice chat for claude-code
    uv                  # Python tool runner (used by mcp.nix)
    ffmpeg
    claude-code
    rustToolchain
    llvmPackages.libclang
    nerd-fonts.dejavu-sans-mono
    # Patched browsers for Playwright; also kept here as a gcroot so
    # nix-collect-garbage doesn't sweep them between home-manager switches.
    # Verified working on aarch64-darwin (ad-hoc signed arm64 bundles).
    playwright-driver.browsers
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    NIX_BUILD_SHELL = "bash";
    # Point Playwright at Nix-managed browsers; suppress its self-download.
    # These browsers only work with a matching Playwright release — see the
    # note on playwright-mcp in ./mcp.nix.
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  # Programs
  programs.bash = {
    enable = true;
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
        # Cover the terminal encodings of Ctrl+Space.
        ble-bind -m auto_complete -f 'C-@'  auto_complete/insert
        ble-bind -m auto_complete -f 'C-SP' auto_complete/insert
        ble-bind -m auto_complete -f 'NUL'  auto_complete/insert

        # Cursor styles: underline for normal, beam for insert (no blinking)
        ble-bind -m vi_nmap --cursor 4   # steady underline
        ble-bind -m vi_imap --cursor 6   # steady beam
        ble-bind -m vi_omap --cursor 4   # steady underline
        ble-bind -m vi_xmap --cursor 4   # steady underline
        ble-bind -m vi_smap --cursor 4   # steady underline

        # System clipboard bridge. Platform-specific tools are resolved at
        # build time; these wrappers give the vi-register hook one interface
        # on both Wayland and macOS. __clip_copy takes the text as $1.
        function __clip_copy  { ${clipCopy}; }
        function __clip_paste { ${clipPaste}; }

        # System clipboard integration via + register
        # Hook into vi register system for + (code 43) and * (code 42)
        blehook/eval-after-load keymap_vi '
          # Override to intercept + and * registers
          function ble/keymap:vi/register#set {
            local reg=$1 type=$2 content=$3
            # Sync to system clipboard for + (43) and * (42) registers
            if [[ $reg == 43 || $reg == 42 ]]; then
              { __clip_copy "$content" 2>/dev/null & disown; } 2>/dev/null
            fi
            # Store in register array
            _ble_keymap_vi_register["$reg"]=$type/$content
          }

          # Override to read from clipboard for + and * registers
          function ble/keymap:vi/register#load {
            local reg=$1
            if [[ $reg == 43 || $reg == 42 ]]; then
              local content
              content=$(__clip_paste 2>/dev/null)
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

        # Keep Escape responsive while allowing terminal key sequences to arrive.
        stty time 0 2>/dev/null || true
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

  # Terminal
  programs.alacritty = {
    enable = true;

    settings = {
      # A login shell on macOS loads Home Manager session variables from ~/.profile.
      terminal.shell = if isDarwin then {
        program = "${pkgs.bash}/bin/bash";
        args = [ "--login" ];
      } else "${pkgs.bash}/bin/bash";
      font = {
        normal = {
          # Core Text requires the patched font's exact family name.
          family = if isDarwin then "DejaVuSansM Nerd Font Mono" else "DejaVu Sans Mono";
          style = "Regular";
        };
        size = 12.0;
      };

      window = {
        # macOS has no server-side decorations worth drawing; "buttonless"
        # keeps the drag area without the traffic lights.
        decorations = if isDarwin then "buttonless" else "full";
        opacity = opacity;
      } // lib.optionalAttrs isDarwin {
        # Treat both Option keys as Alt so Meta-prefixed readline/ble.sh
        # bindings work the same as they do under Sway.
        option_as_alt = "Both";
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

  # Primary terminal; Alacritty remains configured as a fallback.
  programs.ghostty = {
    enable = true;
    package = if isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

    # Disable Ghostty shell integration and its features to avoid conflicts with ble.sh.
    enableBashIntegration = false;

    settings = {
      shell-integration = "none";

      font-family = if isDarwin then "DejaVuSansM Nerd Font Mono" else "DejaVu Sans Mono";
      font-size = 12;

      background = colors.background;
      foreground = colors.foreground;
      background-opacity = opacity;

      cursor-color = accent.primary;
      selection-background = accent.dim;
      selection-foreground = colors.bright.white;

      # Tile at native size and keep the raster opacity consistent with rasterOnBg.
      background-image = "${dotTile}";
      background-image-repeat = true;
      background-image-fit = "none";
      background-image-opacity = 0.18;

      window-padding-x = 8;
      window-padding-y = 4;

      # Sway draws the border and there are no server-side decorations worth
      # having under a tiling WM; on macOS the native titlebar is still wanted.
      window-decoration = isDarwin;

      confirm-close-surface = false;

      # Each launch is its own process, so one wedged instance that opens
      # windows without spawning a shell cannot block every new terminal.
      gtk-single-instance = false;

      # Hide the resize overlay during tiling.
      resize-overlay = "never";

      palette = [
        "0=${colors.normal.black}"
        "1=${colors.normal.red}"
        "2=${colors.normal.green}"
        "3=${colors.normal.yellow}"
        "4=${colors.normal.blue}"
        "5=${colors.normal.magenta}"
        "6=${colors.normal.cyan}"
        "7=${colors.normal.white}"
        "8=${colors.bright.black}"
        "9=${colors.bright.red}"
        "10=${colors.bright.green}"
        "11=${colors.bright.yellow}"
        "12=${colors.bright.blue}"
        "13=${colors.bright.magenta}"
        "14=${colors.bright.cyan}"
        "15=${colors.bright.white}"
      ];
    } // lib.optionalAttrs (!isDarwin) {
      # See ghosttyCss at the top of this file. Guarded rather than set
      # unconditionally so the macOS build is never asked to validate a GTK
      # option, and so the stylesheet is not built on a machine with no GTK.
      gtk-custom-css = "${ghosttyCss}";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "ZeroSync" = {
        HostName = "168.119.139.152";
        User = "root";
      };
      "ideal" = {
        HostName = "89.167.40.38";
        User = "root";
      };
      "Mac" = {
        HostName = "192.168.1.190";
        User = "lee";
        RequestTTY = "yes";
      };
    };
  };

  programs.gpg = {
    enable = true;
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
}
