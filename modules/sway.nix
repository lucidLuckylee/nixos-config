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

  # Screen sharing (Firefox/Meet, Zoom, OBS) goes through the wlroots portal.
  # It is already pulled in by programs.sway, but it ships a systemd unit whose
  # PATH holds only coreutils/findutils/grep/sed/systemd — none of the output
  # choosers it probes for (wmenu, wofi, rofi, bemenu, fuzzel, slurp). Every
  # request therefore ended in "wlroots: no output found": the browser's own
  # permission prompt succeeded, then no stream ever arrived. Naming slurp by
  # absolute store path sidesteps the PATH entirely — click an output to share.
  xdg.portal.wlr = {
    enable = true;
    settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
    };
  };

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
