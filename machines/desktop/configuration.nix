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

  # Direct cable to the Mac mini, no router in between: fixed address, never
  # the default route. The Mac wakes this port from power-off by magic packet.
  networking.interfaces.enp5s0.wakeOnLan.enable = true;
  networking.networkmanager.ensureProfiles.profiles.mac-link = {
    connection = {
      id = "mac-link";
      type = "ethernet";
      interface-name = "enp5s0";
      autoconnect-priority = 10;
    };
    ethernet.wake-on-lan = 64;  # magic packet
    ipv4 = {
      method = "manual";
      address1 = "10.42.0.2/24";
      never-default = true;
    };
    ipv6.method = "disabled";
  };

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
