{ config, pkgs, lib, ... }:

# Synthesising a Globe (fn) key on a keyboard that has none.
#
# The Mac Mini drives a Cherry PC keyboard (USB vendor 1130, product 35). PC
# keyboards have no Globe/fn key, so every macOS shortcut built on it — window
# tiling, emoji picker, dictation — is simply unreachable.
#
# This remaps Right Command → Globe at the HID layer, which is macOS's own
# per-device modifier mapping (the same mechanism as System Settings →
# Keyboard → Keyboard Shortcuts → Modifier Keys). That matters: Karabiner can
# emit an `fn` key code, but macOS treats several Globe-key functions
# specially and does not reliably honour a synthesised one. Going through
# HIDKeyboardModifierMapping produces a real Globe event.
#
# Why Right Command and not something else:
#   Right Option  — this is a German layout, so Right Option is AltGr and is
#                   required for @ € \ { [ ] } | ~. Untouchable.
#   Caps Lock     — already mapped to Escape (below), which vim needs.
#   Right Control — also free; swap RIGHT_COMMAND for RIGHT_CONTROL below if
#                   you would rather keep Right Command.
# Right Command loses nothing: skhd's `cmd - ...` bindings match the left
# Command key, and macOS treats the two as equivalent everywhere else.
#
# Note this is device-scoped. Plug in a different keyboard and the mapping
# does not apply to it; add its vendor-product pair to `devices` below.
#
# Takes effect at next login (or when the keyboard is replugged).

let
  # Apple HID usage codes, as used by HIDKeyboardModifierMapping.
  # Page 0x07 is the standard keyboard page; 0xFF is Apple's vendor page.
  ESCAPE        = 30064771113;   # 0x700000029
  CAPS_LOCK     = 30064771129;   # 0x700000039
  LEFT_OPTION   = 30064771298;   # 0x7000000E2
  LEFT_COMMAND  = 30064771299;   # 0x7000000E3
  RIGHT_OPTION  = 30064771302;   # 0x7000000E6  (AltGr — leave alone)
  RIGHT_COMMAND = 30064771303;   # 0x7000000E7
  GLOBE         = 1095216660483; # 0xFF00000003

  # vendor-product-interface, as it appears in the preference key
  cherryKeyboard = "1130-35-0";

  mapping = [
    # Preserved from the existing configuration
    { src = LEFT_COMMAND;  dst = LEFT_COMMAND; }
    { src = LEFT_OPTION;   dst = LEFT_OPTION; }
    { src = RIGHT_OPTION;  dst = RIGHT_OPTION; }
    { src = CAPS_LOCK;     dst = ESCAPE; }
    # The change
    { src = RIGHT_COMMAND; dst = GLOBE; }
  ];

  entry = m: ''
    <dict>
      <key>HIDKeyboardModifierMappingSrc</key><integer>${toString m.src}</integer>
      <key>HIDKeyboardModifierMappingDst</key><integer>${toString m.dst}</integer>
    </dict>'';

  plistArray = ''
    <array>${lib.concatMapStrings entry mapping}
    </array>'';
in {
  # Written with `defaults -currentHost`: modifier mappings live in the ByHost
  # preference domain, which system.defaults.CustomUserPreferences cannot
  # reach (it writes to the plain domain), hence the activation script.
  #
  # nix-darwin runs all activation as root now (the postUserActivation hook was
  # removed), but `-currentHost` resolves against the *invoking* user's ByHost
  # domain — as root it would write root's preferences and do nothing useful.
  # Hence the drop back to the primary user.
  system.activationScripts.postActivation.text = ''
    echo "configuring keyboard modifier mapping (Right Command → Globe)…" >&2
    sudo -u ${config.system.primaryUser} /usr/bin/defaults -currentHost write -g \
      "com.apple.keyboard.modifiermapping.${cherryKeyboard}" \
      '${plistArray}'
  '';
}
