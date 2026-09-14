{ ... }:

# NixOS home entry point. macOS imports shared.nix through darwin.nix.

{
  imports = [
    ./shared.nix
    ./linux.nix
  ];
}
