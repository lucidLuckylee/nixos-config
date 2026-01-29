{ config, pkgs, ... }:

let
  colors = {
    foreground = "#ffd5d5";
    background = "#000000";
    normal = {
      black = "#2A2A2A";
      white = "#EEDFC7";
      red = "#a81313";
      green = "#44dd88";
      yellow = "#FFBF00";
      blue = "#2040A0";
      magenta = "#8D008D";
      cyan = "#008D8D";
    };
    bright = {
      black = "#000000";
      white = "#EEDFC7";
      red = "#D82626";
      green = "#88FFAA";
      yellow = "#FFDF44";
      blue = "#2040F0";
      magenta = "#AD008D";
      cyan = "#00ADAD";
    };
  };
  mod = "Mod4";
in {
  imports = [ ./common.nix ];

  # Add laptop-specific packages
  home.packages = with pkgs; [
    brightnessctl
  ];

  # Add laptop-specific i3status modules
  programs.i3status.modules = {
    "wireless _first_" = {
      position = 0;
      settings = {
        color_good = colors.normal.green;
        format_up = "%essid%quality %bitrate 󱚽 ";
        format_down = "󰖪 ";
        format_bitrate = "%g%cb/s";
      };
    };
    "battery 0" = {
      position = 3;
      settings = {
        format = "%status %percentage (%remaining)";
        format_percentage = "%.02f%s";
        status_chr = "󰂄";
        status_bat = "󱊡";
        status_full = "󰁹";
        low_threshold = "5";
        threshold_type = "percentage";
        path = "/sys/class/power_supply/BAT%d/uevent";
      };
    };
  };

  # Add laptop-specific Sway keybindings for brightness control
  wayland.windowManager.sway.config.keybindings = pkgs.lib.mkOptionDefault {
    "--locked XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
    "--locked XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
  };
}
