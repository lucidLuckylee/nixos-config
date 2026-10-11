{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/users.nix
    ../../modules/sway.nix
    ../../modules/overlays.nix
  ];

  networking.hostName = "desktop";

  # Wake from power-off by magic packet over the wired port (Mac mini connects here).
  networking.interfaces.enp5s0.wakeOnLan.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      AllowUsers = [ "lucy" ];
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Private key is encrypted in pass under ssh/desktop.
  users.users.lucy.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWue8yfSQOLcpmyp/M3+0xGdB4ci7xnhA6ZUXeGFW1/ lucy desktop access"
  ];

  # ── NVIDIA GPU ────────────────────────────────────────────────────
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;  # Proprietary driver (required for GTX 1080)
  };

  # Never suspend; the machine is powered off and woken instead.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Load nvidia-drm before sway starts; otherwise it replaces simpledrm mid-startup and sway aborts.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # ── WIFI CARD FENVI AX900 + BT5.4 ─────────────────────────────────
  hardware.enableRedistributableFirmware = true;

  home-manager.users.lucy.imports = [ ../../home/desktop.nix ];
}
