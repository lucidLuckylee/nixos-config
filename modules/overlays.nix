{ ... }:

{
  # Package overlays carried locally until the fixes land upstream in nixpkgs.
  nixpkgs.overlays = [
    # ble.sh: in a sandboxed build (`/usr/bin/env` is absent) the build-time
    # helper `make_command.sh` fails its `#!/usr/bin/env bash` shebang, so
    # mwg_pp.awk silently emits empty key-binding hashes (`local hash=''`).
    # The result is a ble.sh that attaches but swallows all keyboard input.
    # Patching the shebang to the sandbox's bash restores the hashes.
    #
    # Upstream report + fix: https://github.com/akinomyoga/ble.sh/issues
    # Remove once the `patchShebangs make_command.sh` fix is in our nixpkgs.
    (final: prev: {
      blesh = prev.blesh.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          patchShebangs --build make_command.sh
        '';
      });
    })
  ];
}
