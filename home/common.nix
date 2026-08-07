{ ... }:

# NixOS home-manager entrypoint.
#
# The configuration was split so it can be shared with the macOS machine:
#   ./shared.nix — cross-platform (packages, bash + ble.sh, Alacritty, git, ssh)
#   ./linux.nix  — Wayland session, systemd user services, Linux-only packages
#
# The macOS counterpart is ./darwin.nix, which imports ./shared.nix only.

{
  imports = [
    ./shared.nix
    ./linux.nix
  ];
}
