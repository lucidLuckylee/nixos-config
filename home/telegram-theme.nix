{ pkgs, ... }:

# A Telegram Desktop theme in the same colours as the rest of the session.
#
# ── Why this ships as a zip ─────────────────────────────────────────
# The obvious thing is to write a bare .tdesktop-palette and load it from the
# UI. That does not work on 7.x, and the binary says why. "Open palette file"
# and "Palette (*.tdesktop-palette)" sit in the string table wedged between
# "Open crash log file", "Open DC endpoints" and "Save detailed log" — they
# belong to the debug panel, not to Chat Settings. Alongside them is
#
#   Theme: Could not loadColorScheme from non-zip.
#
# which is the loader saying what it actually expects. So the deliverable is a
# .tdesktop-theme: a zip with the palette inside it as colors.tdesktop-palette.
#
# ── Applying it ─────────────────────────────────────────────────────
# Telegram registers no MIME handler for theme files (its .desktop file claims
# only x-scheme-handler/tg and tonsite), so there is nothing to double-click.
# The route that works is the one themes are normally shared by:
#
#   Telegram → Saved Messages → attach the .tdesktop-theme file below → send it
#   → click the message → Apply theme
#
# The active theme then lives in Telegram's binary settings blob (tdata), which
# nothing outside the app can write — hence a one-time manual step rather than
# a fully declarative one. Re-sending the file after a palette change re-applies
# it.
#
# ── On completeness ─────────────────────────────────────────────────
# Every key below was checked against the strings in telegram-desktop 7.0.2
# before being written here, so there are no invented names. This is still a
# *partial* palette — Telegram's full set runs to several hundred keys and the
# rest are left to fall back to the built-in dark theme. If a release ever
# rejects a partial file outright, the fix is to start from Telegram's own
# exported default palette and paste these values over it; the colours here are
# the answer either way.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;
  dotGap = theme.dotGap;

  # ── Bubble and selection shades ─────────────────────────────────────
  # Not in colors.nix because nothing else wants them: they are the rungs
  # between accent.panel and accent.line that a chat needs and no other app
  # does. Incoming bubbles sit on `panel` so they match the Firefox address
  # bar; outgoing sit one rung up so the two are separable at a glance without
  # either becoming a bright slab behind a wall of text.
  msgOut     = "#124C5C";
  msgInSel   = "#124450";
  msgOutSel  = "#1A6272";

  # The selected conversation. An earlier version filled this row with
  # accent.primary — a full-width bar of neon cyan down the sidebar, which is
  # what made the theme unusable to look at. A deep teal marks the selection
  # just as clearly and lets the unread badge stay the only saturated thing on
  # screen, which is the job a badge is for.
  dialogSel  = "#10485A";

  palette = {
    # Window shell
    windowBg = colors.background;
    windowFg = accent.textBright;
    windowBgOver = accent.panel;
    windowBgRipple = accent.line;
    windowFgOver = accent.textBright;
    windowSubTextFg = accent.textDim;
    windowBoldFg = accent.textBright;
    windowBgActive = accent.primary;
    windowFgActive = colors.background;
    windowActiveTextFg = accent.primary;
    windowShadowFg = "#000000";

    # Title bar
    titleBg = colors.background;
    titleBgActive = colors.background;
    titleFg = accent.textDim;
    titleFgActive = accent.textBright;

    # Chat list. The selected conversation gets a filled neon row with dark
    # text on it — the same treatment the focused workspace gets in the sway
    # bar, so "this is the active thing" looks identical in both places.
    dialogsBg = colors.background;
    dialogsBgOver = accent.panel;
    dialogsNameFg = accent.textBright;
    dialogsTextFg = accent.textDim;
    dialogsDateFg = accent.muted;
    dialogsBgActive = dialogSel;
    dialogsNameFgActive = accent.textBright;
    dialogsTextFgActive = accent.textDim;
    dialogsUnreadBg = accent.primary;
    dialogsUnreadFg = colors.background;

    # Message bubbles
    msgInBg = accent.panel;
    msgOutBg = msgOut;
    msgInBgSelected = msgInSel;
    msgOutBgSelected = msgOutSel;
    # Date separators and "joined the group" notices float directly on the
    # rastered background, so this one is translucent — Telegram's palette
    # grammar takes #rrggbbaa — and the dots read through it.
    msgServiceBg = "${accent.panel}CC";
    msgServiceFg = accent.textDim;
    historyTextInFg = accent.textBright;
    historyTextOutFg = accent.textBright;
    historyComposeAreaBg = accent.panel;
    historyComposeAreaFg = accent.textBright;

    # Menus, scrollbars, dialogs
    menuBg = colors.background;
    menuBgOver = accent.panel;
    menuIconFg = accent.primary;
    scrollBg = colors.background;
    scrollBarBg = accent.line;
    boxBg = colors.background;
    boxTextFg = accent.textBright;
    activeButtonBg = accent.primary;
    activeButtonFg = colors.background;
    sideBarBg = colors.background;
    sideBarTextFg = accent.textDim;
  };

  # Telegram's palette grammar is one `key: #rrggbb;` per line.
  renderPalette = builtins.concatStringsSep "\n"
    (builtins.attrValues
      (builtins.mapAttrs (k: v: "${k}: ${v};") palette));

  paletteText = ''
    // Cozy cyberpunk — generated from home/colors.nix, do not edit by hand.

    ${renderPalette}
  '';

  # ── The chat background ─────────────────────────────────────────────
  # Same raster as the terminal and the Firefox chrome: #06121A ground with a
  # dot every 8px in the precomputed accent.rasterOnBg, so all three surfaces
  # are the same screen.
  #
  # The tiling is chosen by *filename*, not by a flag — the binary carries
  # "tiled.png" and "tiled.jpg" next to "background.png"/"background.jpg", and
  # naming it tiled.png is what stops Telegram stretching one 64px square
  # across the whole chat.
  #
  # 64x64 rather than a bare 8x8 tile: it holds the same 8px pitch but survives
  # Telegram's HiDPI scaling without the pattern turning into mush.
  tiledBackground = pkgs.runCommand "tiled.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    ''
      magick -size ${toString dotGap}x${toString dotGap} xc:'${colors.background}' \
        -fill '${accent.rasterOnBg}' -draw 'point 0,0' \
        -write mpr:t +delete \
        -size 64x64 tile:mpr:t PNG24:$out
    '';

  # The zip Telegram will actually accept. Both member names are exact and both
  # were read out of the binary rather than guessed.
  #
  # -X drops extra file attributes and timestamps so the archive is
  # reproducible; without it the zip embeds the build date and the store hash
  # changes on every rebuild for no reason.
  themeFile = pkgs.runCommand "cozy-cyberpunk.tdesktop-theme"
    { nativeBuildInputs = [ pkgs.zip ]; }
    ''
      mkdir -p build
      cp ${pkgs.writeText "colors.tdesktop-palette" paletteText} \
        build/colors.tdesktop-palette
      cp ${tiledBackground} build/tiled.png
      cd build
      zip -X -q "$out" colors.tdesktop-palette tiled.png
    '';
in {
  # The zip is the one to use — send it to Saved Messages and click it.
  home.file.".local/share/telegram-theme/cozy-cyberpunk.tdesktop-theme".source =
    themeFile;

  # The bare palette is kept alongside it. It is not loadable from the normal
  # UI, but it is what Telegram's debug panel takes, and it is far easier to
  # read than a zip when checking what a colour resolved to.
  home.file.".local/share/telegram-theme/cozy-cyberpunk.tdesktop-palette".text =
    paletteText;
}
