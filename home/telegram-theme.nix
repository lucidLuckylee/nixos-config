{ pkgs, ... }:

# Telegram accepts a .tdesktop-theme archive. Apply it by sending the file
# to Saved Messages, opening the message and choosing Apply theme. Repeat after
# palette changes; the active theme is stored in Telegram's private settings.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent dotGap;

  # Telegram-specific bubble and selection shades.
  msgOut     = "#124C5C";
  msgInSel   = "#124450";
  msgOutSel  = "#1A6272";

  # Use a subdued conversation selection so unread badges remain prominent.
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

  # The filename tiled.png enables tiling. A 64px tile preserves the shared
  # raster pitch under Telegram's HiDPI scaling.
  tiledBackground = pkgs.runCommand "tiled.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    ''
      magick -size ${toString dotGap}x${toString dotGap} xc:'${colors.background}' \
        -fill '${accent.rasterOnBg}' -draw 'point 0,0' \
        -write mpr:t +delete \
        -size 64x64 tile:mpr:t PNG24:$out
    '';

  # Telegram requires these archive member names. -X omits ZIP extra attributes.
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
