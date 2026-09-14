{ pkgs, ... }:

# Terminal Telegram client, using the terminal palette and raster.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent;

  # Wait before returning to tg, which redraws immediately when the viewer exits.
  # Let chafa detect the terminal's supported graphics format.
  viewImage = pkgs.writeShellApplication {
    name = "tg-view-image";
    runtimeInputs = [ pkgs.chafa ];
    text = ''
      chafa --clear "$1"
      printf '\n  \033[36m[ any key to return, o to open in imv ]\033[0m'
      read -rsn1 key || key=""
      printf '\n'
      if [ "$key" = "o" ]; then
        ${pkgs.imv}/bin/imv "$1" >/dev/null 2>&1 &
      fi
    '';
  };

  # tg looks files up by MIME type through mailcap. With no mailcap anywhere on
  # the system, findmatch returns nothing and pressing `l` on an image silently
  # does nothing at all — which is what "I can't see images" was.
  mailcap = pkgs.writeText "tg-mailcap" ''
    image/*; ${viewImage}/bin/tg-view-image %s; needsterminal
    video/*; ${pkgs.mpv}/bin/mpv --loop-file=inf %s
    audio/*; ${pkgs.mpv}/bin/mpv --no-video %s
    application/pdf; ${pkgs.zathura}/bin/zathura %s
    text/*; ''${PAGER:-less} %s; needsterminal
    application/*; ${pkgs.xdg-utils}/bin/xdg-open %s
  '';
  # mailcap supports type/*, not */*; application/* handles other attachments.

  # Prompt for the phone number before curses starts and keep it outside the
  # store in ~/.config/tg/phone (0600). tg imports only uppercase config names.
  configText = ''
    # Generated from home/colors.nix — do not edit by hand.
    import os

    _phone_file = os.path.expanduser("~/.config/tg/phone")

    if os.path.isfile(_phone_file):
        PHONE = open(_phone_file).read().strip()
    else:
        # A managed conf.py bypasses tg's first-run phone prompt, so supply it here.
        print("Enter your phone number in international format "
              "(including country code)")
        PHONE = input("phone> ").strip()
        if not PHONE.startswith("+"):
            PHONE = "+" + PHONE
        os.makedirs(os.path.dirname(_phone_file), exist_ok=True)
        with open(os.open(_phone_file, os.O_CREAT | os.O_WRONLY, 0o600),
                  "w") as _f:
            _f.write(PHONE + "\n")

    # Use cool ANSI colours for usernames, reserving red and yellow for alerts.
    USERS_COLORS = (14, 6, 12, 4, 10, 2, 13, 5)

    # Match the editor used everywhere else rather than the `vi` default.
    EDITOR = "nvim"
    LONG_MSG_CMD = "nvim + -c 'startinsert' {file_path}"

    # Use fzf instead of tg's default ranger file picker.
    FILE_PICKER_CMD = "sh -c 'fzf > {file_path}'"

    VIEW_TEXT_CMD = "less"
    DOWNLOAD_DIR = os.path.expanduser("~/Downloads/")

    # Without this tg calls mailcap.getcaps(), which scans ~/.mailcap and
    # /etc/mailcap — neither of which exists here, so every image resolved to
    # no handler and opening one did nothing.
    MAILCAP_FILE = "${mailcap}"
  '';
in {
  home.packages = with pkgs; [
    tg
    fzf     # tg's file picker, and generally useful at the prompt

    # The mailcap handlers above reference these by store path, so tg works
    # whether or not they are on PATH. They are installed anyway because
    # wanting an image viewer outside tg is the normal case, not the exception.
    chafa   # inline images in the terminal
    imv     # the windowed viewer, for when the inline one is not enough
    mpv     # video and audio
    zathura # pdf
  ];

  xdg.configFile."tg/conf.py".text = configText;

  # tg runs `find` over its cache before the directory exists, so the very
  # first launch prints a stray "No such file or directory". Creating it up
  # front keeps that off the screen.
  home.file.".cache/tg/files/.keep".text = "";

  # Use the shared palette for fzf.
  home.sessionVariables.FZF_DEFAULT_OPTS = builtins.concatStringsSep " " [
    "--color=bg+:${accent.panel}"
    "--color=bg:-1"
    "--color=fg:${accent.textDim}"
    "--color=fg+:${accent.textBright}"
    "--color=hl:${accent.primary}"
    "--color=hl+:${accent.primary}"
    "--color=info:${accent.primary}"
    "--color=prompt:${accent.primary}"
    "--color=spinner:${accent.primary}"
    "--color=pointer:${accent.hot}"
    "--color=marker:${accent.hot}"
    "--color=header:${accent.line}"
    "--color=border:${accent.line}"
    "--color=gutter:${colors.background}"
    "--border=sharp"
  ];
}
