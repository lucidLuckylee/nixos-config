{ config, pkgs, ... }:

let
  # Outputs are identified by "make model serial", NOT by connector name.
  #
  # Connector names are handed out by the driver and they move. This file said
  # DP-1; the AOC is currently DP-3, so its entire output block — mode, position,
  # background — had silently never applied, and a 144Hz panel had been running
  # at 60Hz sitting at x=3600 instead of the origin. There is nothing to notice,
  # because sway accepts an output block for a connector that does not exist and
  # simply keeps it in case one turns up. The identifier does not move.
  #
  # Both tools that need to name an output here accept this form:
  #
  #   swaymsg -t get_outputs        # make / model / serial
  #   mpvpaper --help-output        # prints Output: and Identifier: for each
  primary = "AOC 27G1G4 0x00015EE6";
  secondary = "ViewSonic Corporation VX2268wm RAG093300987";
in {
  imports = [ ./common.nix ];

  wayland.windowManager.sway.config = {
    # Dual-monitor layout: 144Hz primary on the left, 120Hz secondary right of
    # it. The two screens are different shapes — 16:9 and 16:10 — so they do not
    # share a wallpaper. The secondary gets its own still, cropped to 1680x1050
    # rather than stretched from the 1920x1080 one; wallpaper/grade.sh makes it.
    #
    # Sway applies `output *` before named outputs, so the wildcard background in
    # home/linux.nix stays the default and this overrides it for the one screen
    # that needs a different image.
    output = {
      "${primary}" = {
        mode = "1920x1080@144.001Hz";
        pos = "0 0";
      };
      "${secondary}" = {
        mode = "1680x1050@120Hz";
        pos = "1920 0";
        bg = "${./wallpaper2.jpg} fill";
      };
    };

    # Without these, sway puts a workspace wherever it happens to be focused and
    # numbers it from whatever is free, which is how a fresh session came up on
    # workspace 10. Pinning 1 and 2 means each screen always starts on its own,
    # and mod+1 / mod+2 always go to the same physical monitor.
    workspaceOutputAssign = [
      {
        workspace = "1";
        output = primary;
      }
      {
        workspace = "2";
        output = secondary;
      }
    ];
  };

  # The animated wallpaper is composed for 1920x1080 and would be cropped on the
  # 16:10 screen — and would cover the still that screen was just given. Pin it
  # to the primary. mpvpaper matches this identifier the same way sway does.
  wallpaper.animatedOutput = primary;
}
