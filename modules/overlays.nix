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

    # tg needs the mailcap_fix submodule; importing the package breaks attachments.
    # Fail the replacement if upstream changes the import.
    (final: prev: {
      tg = prev.tg.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace tg/utils.py \
            --replace-fail 'import mailcap_fix as mailcap' \
                           'from mailcap_fix import mailcap'
        '';
      });
    })
  ];
}
