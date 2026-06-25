{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Add laptop-specific packages
  home.packages = with pkgs; [
    brightnessctl
  ];

  # Add laptop-specific i3status modules
  programs.i3status.modules = {
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
