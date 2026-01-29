{ config, pkgs, ... }:

{
  users.groups.lucy = {};
  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    group = "lucy";
    extraGroups = [ "wheel" "seat" "networkmanager" "libvirtd" "kvm" ];
    shell = pkgs.zsh;
    # Podman rootless containers
    subGidRanges = [{ count = 65536; startGid = 100000; }];
    subUidRanges = [{ count = 65536; startUid = 100000; }];
  };
}
