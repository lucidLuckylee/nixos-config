{ config, pkgs, nvim, ... }:

{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  environment.systemPackages = with pkgs; [
    swaybg
    swaylock
    waybar
    alacritty
    wl-clipboard
    grim slurp  # screenshots
    nvim.packages.x86_64-linux.default
    distrobox
  ];

  # Required to start up sway
  services.seatd.enable = true;

  # Auto-login to tty1 and start Sway
  services.getty.autologinUser = "lucy";
  environment.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      exec sway --unsupported-gpu
    fi
  '';

  # NVIDIA + Wayland compatibility
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";  # Fix invisible/glitchy cursor
    NIXOS_OZONE_WL = "1";           # Electron apps use Wayland
  };
}
