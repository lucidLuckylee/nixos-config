{
  # ── Cozy cyberpunk ──────────────────────────────────────────────────
  # Sampled from home/wallpaper.jpg: a hammock slung in a scrapyard ship
  # interior, lit by amber sodium lamps on one side and neon signage on the
  # other, with a deep blue porthole between them.
  #
  # The palette follows that lighting rather than inventing one. Neon cyan is
  # the primary accent — it is what the signs in the picture actually are, and
  # it is the colour focus rings, active workspaces and prompts are drawn in.
  # Amber is kept as the warm counterpoint so the scheme does not read as a
  # uniform blue wash; it carries warnings and the urgent state.
  #
  # Contrast against `background` was checked for every entry (WCAG relative
  # luminance). Everything used as *text* clears 4.1:1 and most clear 6:1; the
  # two `black` entries sit far below that on purpose — they are border and
  # panel fills, never a foreground.
  #
  # `normal` and `bright` are handed verbatim to Alacritty's colours in
  # ./shared.nix, so they must keep exactly the eight ANSI keys and no others.
  # Anything else the configs need goes in the semantic block further down.
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

  # ── Semantic roles ──────────────────────────────────────────────────
  # Named by job rather than by hue, so the window manager and browser configs
  # do not have to re-decide "which colour is focus?" in three places. Kept
  # outside `colors` above because Alacritty would reject the extra keys.
  accent = {
    primary   = "#3EE0C8";  # focus, active workspace, cursor      (bright.cyan)
    secondary = "#2A9DE0";  # links, selection                     (bright.blue)
    warm      = "#FFA940";  # urgent, warnings                     (bright.yellow)
    dim       = "#1E4155";  # inactive borders, panel fill         (bright.black)
    surface   = "#0C1F2B";  # one step up from the background
    muted     = "#7FA3B0";  # de-emphasised text

    # ── Vivid set ─────────────────────────────────────────────────────
    # The four above are the restrained versions, and they suit the window
    # manager: sway shows a lot of bare border and a dim slate keeps unfocused
    # frames genuinely quiet. A browser is mostly filled chrome, and at that
    # size the same slate reads as flat grey and drops the whole window out of
    # the picture the palette came from.
    #
    # These are the same roles pulled toward cyan and brightened. Contrast
    # against the background improves rather than degrades: textDim goes from
    # 7.0:1 to 10.9:1, and `line` from 1.8:1 to 2.7:1, so borders are actually
    # visible instead of implied.
    panel      = "#08303A";  # surface — committed dark cyan, no grey left in it
    line       = "#1C6273";  # borders — cyan-tinted, not slate
    textDim    = "#8FCEDC";  # secondary text that is still cyan, not grey
    textBright = "#D6F5FA";  # primary text, a step above `foreground`

    # The one warm signal in an otherwise entirely cyan browser. Used for
    # toolbar icons: against this much teal a hot red is the only thing that
    # stays legible as a *different kind* of element rather than more chrome,
    # and it picks up the neon signage in the wallpaper from the other side of
    # the colour wheel. 5.4:1 on the background.
    hot        = "#FF3B5C";

    # The dot colour for the web-content raster, which cannot reuse
    # accent.primary. That layer blends with `lighten`, so the dots must sit
    # just above `panel` in brightness: bright enough to read against the tint,
    # dim enough that they stay below photographic content and so vanish over
    # it. A neon dot here would show over everything, which is the whole thing
    # being avoided.
    rasterDot  = "#135260";

    # The colour a terminal dot actually resolves to on screen: background
    # #06121A with accent.primary composited over it at Ghostty's
    # background-image-opacity of 0.18. Firefox's chrome paints its raster in
    # this flat colour instead of stacking its own translucent layer, so the
    # two surfaces come out pixel-identical rather than merely similar.
    #
    # If the terminal's dot opacity is retuned, recompute:
    #   channel = bg + (primary - bg) * opacity
    rasterOnBg = "#103739";
  };

  opacity = 0.9;
  opacity_alpha_hex = "E5";

  # ── Raster ──────────────────────────────────────────────────────────
  # Spacing in physical pixels between dots in the background raster. Shared
  # so the terminal's tiled PNG (./shared.nix, generated at build time) and
  # Firefox's CSS radial-gradient (./firefox.nix) line up at the same pitch
  # instead of drifting apart when one of them is tweaked.
  #
  # 8 reads as texture. Much below that it turns to noise behind text; much
  # above and it stops being a raster and starts being visible polka dots.
  dotGap = 8;
}
