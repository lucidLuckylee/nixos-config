{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Dual-monitor layout: 144Hz primary on DP-1, 120Hz secondary on DVI-D-1
  wayland.windowManager.sway.config.output = {
    "DP-1" = {
      mode = "1920x1080@144.001Hz";
      pos = "0 0";
    };
    "DVI-D-1" = {
      mode = "1680x1050@120Hz";
      pos = "1920 0";
    };
  };
}
