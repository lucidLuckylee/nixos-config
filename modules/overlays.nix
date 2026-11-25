{ ... }:

{
  # Package overlays carried locally until the fixes land upstream in nixpkgs.
  nixpkgs.overlays = [
    # Fix ble.sh's build helper shebang so sandbox builds generate key-binding hashes.
    # Remove when nixpkgs patches make_command.sh itself.
    (final: prev: {
      blesh = prev.blesh.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          patchShebangs --build make_command.sh
        '';
      });
    })
  ];
}
