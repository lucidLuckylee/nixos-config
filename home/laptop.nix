{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Add laptop-specific packages
  home.packages = with pkgs; [
    brightnessctl
  ];


  # Add laptop-specific Sway keybindings for brightness control
  wayland.windowManager.sway.config.keybindings = pkgs.lib.mkOptionDefault {
    "--locked XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
    "--locked XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
  };
}
