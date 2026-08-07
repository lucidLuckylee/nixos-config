{ config, pkgs, lib, ... }:

# Cross-platform home-manager configuration.
#
# Everything in here must evaluate on both NixOS and nix-darwin. Anything that
# needs a Wayland session, systemd, or Linux-only packages belongs in
# ./linux.nix; anything macOS-specific belongs in ./darwin.nix.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  opacity = theme.opacity;

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # Stable Rust toolchain assembled from fenix components
  rustToolchain = pkgs.fenix.combine (with pkgs.fenix.stable; [
    cargo
    rustc
    rustfmt
    clippy
    rust-src
    rust-analyzer
  ]);

  # Clipboard bridge for the ble.sh vi-register hook below. Each platform keeps
  # its native call shape rather than being forced through a common one:
  # wl-copy takes the text as an argument, pbcopy reads stdin.
  #
  # Note the newline asymmetry — wl-copy appends a trailing newline when given
  # an argument (that is its documented default; --trim-newline suppresses it),
  # whereas `printf '%s'` into pbcopy does not. Left as-is deliberately: this
  # preserves the exact Linux behaviour that was here before, and no-newline is
  # the better answer for charwise yanks on the Mac. Copy takes the text as $1.
  clipCopy = if isDarwin
    then "printf '%s' \"$1\" | /usr/bin/pbcopy"
    else "${pkgs.wl-clipboard}/bin/wl-copy -- \"$1\"";
  clipPaste = if isDarwin
    then "/usr/bin/pbpaste"
    else "${pkgs.wl-clipboard}/bin/wl-paste --no-newline";
in {
  imports = [
    ./mcp.nix
  ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    htop
    ripgrep
    jq
    tmux
    gh
    python3
    blesh
    unzip
    wakeonlan
    pass                # password-store
    pinentry-curses     # GPG passphrase entry
    pv
    sox                 # Voice chat for claude-code
    uv                  # Python tool runner (shared by mcp.nix + telegram-claude.nix)
    devenv
    ffmpeg
    claude-code
    rustToolchain
    nerd-fonts.dejavu-sans-mono
    # ~2.2 GiB download, 4.9 GiB on disk. This is the top-level scheme, not
    # texlive.combined.scheme-full — the combined.* attributes are deprecated
    # and are being removed in nixpkgs 27.05.
    texliveFull
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
        ble-bind -m auto_complete -f 'C-@' auto_complete/insert

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

        # Reduce escape key timeout for faster mode switching.
        #
        # `stty time 0` sets the non-canonical read timeout (VTIME). On macOS
        # this resolves to GNU coreutils' stty rather than BSD /bin/stty, and
        # the underlying tcsetattr refuses the setting — printing "unable to
        # perform all requested operations" on every shell start. The terminal
        # is in canonical mode here so the setting is a no-op anyway; keep it
        # for Linux and let it fail quietly elsewhere.
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
      terminal.shell = "${pkgs.bash}/bin/bash";
      font = {
        normal = {
          # nerd-fonts.dejavu-sans-mono does not register a "DejaVu Sans Mono"
          # family — it patches the glyphs and renames to "DejaVuSansM Nerd
          # Font", with a Mono variant that forces every glyph to a single
          # cell (what a terminal wants) and a Propo variant that does not.
          # fontconfig fuzzy-matches the old name on Linux, so the original
          # spelling keeps working there; macOS Core Text requires an exact
          # match and simply fails to load, so name it precisely.
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

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "ZeroSync" = {
        HostName = "168.119.139.152";
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
