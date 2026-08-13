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

    # tg: opening any attachment fails outright.
    #
    # Python 3.13 dropped the stdlib `mailcap`, and tg switched to the
    # mailcap-fix package to replace it — but it imports the *package* and then
    # calls the module's functions on it:
    #
    #   import mailcap_fix as mailcap
    #   ...
    #   mailcap.getcaps()
    #
    # mailcap_fix/__init__.py only re-exports submodules (`mailcap`,
    # `mailcap_fix`, `mailcap_original`); the functions live one level down in
    # mailcap_fix.mailcap_fix. So every call raises
    #
    #   AttributeError: module 'mailcap_fix' has no attribute 'getcaps'
    #
    # and pressing `l` on an image does nothing. The package conveniently
    # aliases `mailcap = mailcap_fix`, so importing that submodule instead is
    # the whole fix.
    #
    # replace-fail rather than replace-quiet on purpose: if a future tg rewrites
    # this import, the build should stop rather than silently carry a patch that
    # no longer applies.
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
