{ config, pkgs, lib, ... }:

# Map Right Command to Globe on the Cherry PC keyboard; preserve AltGr and
# Caps Lock → Escape. The HID mapping takes effect on login or replug.

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
  # Write the primary user's ByHost domain; ordinary system.defaults targets
  # the wrong preference domain for device-specific modifier mappings.
  system.activationScripts.postActivation.text = ''
    echo "configuring keyboard modifier mapping (Right Command → Globe)…" >&2
    sudo -u ${config.system.primaryUser} /usr/bin/defaults -currentHost write -g \
      "com.apple.keyboard.modifiermapping.${cherryKeyboard}" \
      '${plistArray}'
  '';
}
