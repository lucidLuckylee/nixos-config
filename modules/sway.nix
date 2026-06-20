{ config, lib, pkgs, nvim, ... }:

let
  # Only the desktop uses the NVIDIA proprietary driver, which needs Wayland
  # workarounds the AMD machine does not — and applying them unnecessarily can
  # perturb rendering. Gate them on the driver actually being in use.
  nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
in {
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
      exec sway ${lib.optionalString nvidia "--unsupported-gpu"}
    fi
  '';

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";  # Electron apps use Wayland
  } // lib.optionalAttrs nvidia {
    # NVIDIA-only: force software cursors to avoid invisible/glitchy pointer
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
