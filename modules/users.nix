{ config, pkgs, ... }:

{
  users.groups.lucy = {};
  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    group = "lucy";
    extraGroups = [ "wheel" "seat" "networkmanager" ];
    shell = pkgs.bash;
  };
}
