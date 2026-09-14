{
  # Palette sampled from wallpaper.jpg. Keep normal/bright limited to ANSI keys
  # for Alacritty; application-specific roles belong in accent.
  colors = {
    foreground = "#C2E9F0";   # pale cyan-white, like light through the port
    background = "#06121A";   # deep navy-black, not pure black

    normal = {
      black   = "#123040";
      red     = "#D04156";
      green   = "#35B87A";
      yellow  = "#D98A2B";
      blue    = "#2C86CC";
      magenta = "#A555C0";
      cyan    = "#1FA8A0";
      white   = "#9FBCC6";
    };

    bright = {
      black   = "#1E4155";
      red     = "#E0455A";    # the hammock
      green   = "#5FE87A";    # the small green sign
      yellow  = "#FFA940";    # the sodium lamps
      blue    = "#2A9DE0";    # the porthole
      magenta = "#B45BD8";
      cyan    = "#3EE0C8";    # the neon signage — the primary accent
      white   = "#E6F7FA";
    };
  };

  # Shared semantic colours, separate from the ANSI palette.
  accent = {
    primary   = "#3EE0C8";  # focus, active workspace, cursor      (bright.cyan)
    secondary = "#2A9DE0";  # links, selection                     (bright.blue)
    warm      = "#FFA940";  # urgent, warnings                     (bright.yellow)
    dim       = "#1E4155";  # inactive borders, panel fill         (bright.black)
    surface   = "#0C1F2B";  # one step up from the background
    muted     = "#7FA3B0";  # de-emphasised text

    # Brighter surface and text colours for application chrome.
    panel      = "#08303A";  # surface — committed dark cyan, no grey left in it
    line       = "#1C6273";  # borders — cyan-tinted, not slate
    textDim    = "#8FCEDC";  # secondary text that is still cyan, not grey
    textBright = "#D6F5FA";  # primary text, a step above `foreground`

    # Toolbar icons and other warm highlights.
    hot        = "#FF3B5C";

    # Dim dots for the web-content lighten blend; brighter dots obscure photos.
    rasterDot  = "#135260";

    # Terminal raster composited at 0.18 opacity: bg + (primary - bg) * opacity.
    # Recompute if Ghostty background-image-opacity changes.
    rasterOnBg = "#103739";
  };

  opacity = 0.9;
  opacity_alpha_hex = "E5";

  # Window opacity does not apply to the solid Quickshell surfaces.

  # Raster pitch in pixels, shared by terminal, browser and GTK themes.
  dotGap = 8;
}
