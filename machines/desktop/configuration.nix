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

  # The current Wi-Fi profile uses NetworkManager's default wake setting.
  # 8 = magic packet; takes effect when the connection is next activated.
  networking.networkmanager.connectionConfig."wifi.wake-on-wlan" = 8;
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="net", ATTR{address}=="78:92:9c:dd:76:c9", ATTR{device/power/wakeup}="enabled"
  '';

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
    # Installs the nvidia-suspend/resume units; without them S3 resume hangs.
    powerManagement.enable = true;
  };

  # Samsung SM981 NVMe hangs S3 suspend with deep power states.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # ── WIFI CARD FENVI AX900 + BT5.4 ─────────────────────────────────
  hardware.enableRedistributableFirmware = true;

  home-manager.users.lucy.imports = [ ../../home/desktop.nix ];
}
