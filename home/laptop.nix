{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Add laptop-specific packages
  home.packages = with pkgs; [
    brightnessctl
  ];

  # The battery readout that used to be an i3status module here is on the
  # Quickshell bar now (../home/quickshell/Bar.qml), and it does not need to be
  # declared per machine: UPower says whether there is a battery, so a desktop
  # gets one fewer pill without being told.

  # Add laptop-specific Sway keybindings for brightness control
  wayland.windowManager.sway.config.keybindings = pkgs.lib.mkOptionDefault {
    "--locked XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
    "--locked XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
  };
}
