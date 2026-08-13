{ pkgs, ... }:

# tg — a terminal Telegram client, themed to the session.
#
# ── Why this exists alongside telegram-desktop ──────────────────────
# Telegram Desktop's theme format only carries a background image for the chat
# pane; its sidebar, dialog list and settings take flat colours and nothing
# else, so the raster stops at the chat area and cannot go further.
#
# A terminal client sidesteps that entirely. tg draws with curses, which means
# every colour it uses is one of the terminal's sixteen — the palette Ghostty
# is already configured with in ./shared.nix — and it inherits the dot raster
# for free, because the raster is the terminal's background image and tg is
# simply text drawn on top of it. Nothing here has to reimplement the theme.
#
# What is left to configure is which of those sixteen slots get used, which is
# what USERS_COLORS below does.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;

  # ── The one-time secret ─────────────────────────────────────────────
  # tg needs a phone number before tdlib will start the login, and the library
  # underneath prompts for the code but never for the number itself — so with
  # it unset, first run just fails.
  #
  # It deliberately does not live in this file. It is personal data in a git
  # repository, and conf.py here is a read-only store symlink that cannot be
  # edited afterwards anyway. Instead the generated config reads it at startup
  # from a small writable file next to itself, which is created once by hand
  # and never tracked:
  #
  #   echo '+49...' > ~/.config/tg/phone
  #
  # runpy.run_path only promotes UPPERCASE names into tg's config, so the
  # lowercase helper below is invisible to it.
  configText = ''
    # Generated from home/colors.nix — do not edit by hand.
    import os

    _phone_file = os.path.expanduser("~/.config/tg/phone")
    if os.path.isfile(_phone_file):
        PHONE = open(_phone_file).read().strip()
    else:
        # Without this, tg gets PHONE=None and dies eight frames deep in tdlib
        # with "You must provide bot_token or phone", which says nothing about
        # where to put one. SystemExit from runpy stops it here instead, with
        # the actual instruction.
        raise SystemExit(
            "tg: no phone number configured.\n"
            "\n"
            "  mkdir -p ~/.config/tg\n"
            "  echo '+49...' > ~/.config/tg/phone\n"
            "\n"
            "It is kept out of the flake on purpose: personal data, public "
            "repo, and conf.py is a read-only store symlink."
        )

    # Usernames are coloured by picking from this tuple. The default is
    # range(2, 16) — every colour the terminal has, which in this palette means
    # names showing up in warning-yellow and urgent-red. Restricted here to the
    # cyan half of the palette so the chat stays in one key, and so red and
    # yellow keep meaning "something is wrong" the way they do everywhere else
    # in the session.
    #
    #   14 bright cyan     6 cyan       12 bright blue    4 blue
    #   10 bright green    2 green      13 bright magenta 5 magenta
    USERS_COLORS = (14, 6, 12, 4, 10, 2, 13, 5)

    # Match the editor used everywhere else rather than the `vi` default.
    EDITOR = "nvim"
    LONG_MSG_CMD = "nvim + -c 'startinsert' {file_path}"

    # tg defaults to `ranger --choosefile=...`, which is not installed here and
    # fails silently with "No file was selected". fzf is added below and does
    # the same job in one line: it writes the chosen path to the temp file tg
    # then reads back.
    FILE_PICKER_CMD = "sh -c 'fzf > {file_path}'"

    VIEW_TEXT_CMD = "less"
    DOWNLOAD_DIR = os.path.expanduser("~/Downloads/")
  '';
in {
  home.packages = with pkgs; [
    tg
    fzf   # tg's file picker, and generally useful at the prompt
  ];

  xdg.configFile."tg/conf.py".text = configText;

  # tg runs `find` over its cache before the directory exists, so the very
  # first launch prints a stray "No such file or directory". Creating it up
  # front keeps that off the screen.
  home.file.".cache/tg/files/.keep".text = "";

  # fzf in the same palette, so the picker tg opens does not arrive as the one
  # piece of default-coloured UI in an otherwise themed terminal. This is
  # session-wide rather than tg-only — it is the same fzf either way — and
  # would sit equally well in ./shared.nix if the Mac ever wants it.
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
