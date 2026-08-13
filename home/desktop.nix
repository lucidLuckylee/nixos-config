{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Dual-monitor layout: 144Hz primary on DP-1, 120Hz secondary on DVI-D-1.
  #
  # The two screens are different shapes — 16:9 and 16:10 — so they do not share
  # a wallpaper. DVI-D-1 gets its own still, cropped to 1680x1050 rather than
  # stretched from the 1920x1080 one; see wallpaper/grade.sh for how it is made.
  #
  # Sway applies `output *` before named outputs, so the wildcard background in
  # home/linux.nix is the default and this overrides it for the one screen that
  # needs a different image.
  wayland.windowManager.sway.config.output = {
    "DP-1" = {
      mode = "1920x1080@144.001Hz";
      pos = "0 0";
    };
    "DVI-D-1" = {
      mode = "1680x1050@120Hz";
      pos = "1920 0";
      bg = "${./wallpaper2.jpg} fill";
    };
  };

  # The animated wallpaper is composed for 1920x1080 and would be letterboxed or
  # cropped on the 16:10 screen — and would cover the still that screen was just
  # given. Pin it to the primary.
  wallpaper.animatedOutput = "DP-1";
}
