{ config, pkgs, lib, ... }:

# Manage yabai and skhd with launchd. Remove competing manually installed
# agents. After binary updates, renew their macOS Accessibility permissions.

let
  theme = import ../../home/colors.nix;
  inherit (theme) opacity;

  # Match nix-darwin's yabairc generation without reading the overridden
  # ProgramArguments, which would cause infinite recursion.
  toYabaiConfig = opts:
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList (p: v: "yabai -m config ${p} ${toString v}") opts);

  yabaiCfg = config.services.yabai;
  skhdCfg = config.services.skhd;

  yabaiConfigFile = pkgs.writeScript "yabairc" (
    (if yabaiCfg.config != { } then "${toYabaiConfig yabaiCfg.config}" else "")
    + lib.optionalString (yabaiCfg.extraConfig != "") ("\n" + yabaiCfg.extraConfig + "\n"));

  # The encrypted Nix volume may mount after launchd starts. Use /bin/sh to
  # wait for the executable; a timeout lets KeepAlive retry.
  waitThenExec = binary: args: [
    "/bin/sh"
    "-c"
    ''
      n=0
      while [ ! -x "${binary}" ] && [ $n -lt 120 ]; do
        sleep 1
        n=$((n + 1))
      done
      exec "${binary}" ${args}
    ''
  ];
in {
  # Replace linker-signed signatures with plain ad-hoc signatures so macOS can
  # persist Accessibility grants. Binary updates still require approval.
  nixpkgs.overlays = [
    (final: prev: {
      yabai = prev.yabai.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          ${final.darwin.sigtool}/bin/codesign --force --sign - "$out/bin/yabai"
        '';
      });
      skhd = prev.skhd.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          ${final.darwin.sigtool}/bin/codesign --force --sign - "$out/bin/skhd"
        '';
      });
    })
  ];

  services.yabai = {
    enable = true;

    # Spaces manipulation requires yabai's scripting addition and reduced SIP.
    enableScriptingAddition = false;

    config = {
      # BSP tiling, matching Sway's default layout
      layout = "bsp";
      window_placement = "second_child";
      split_ratio = 0.5;
      auto_balance = "off";

      # Gaps and padding
      top_padding = 0;
      bottom_padding = 4;
      left_padding = 4;
      right_padding = 4;
      window_gap = 4;

      # Matches the Sway `opacity 0.9` window rule
      window_opacity = "on";
      active_window_opacity = 1.0;
      normal_window_opacity = opacity;
      window_shadow = "off";

      # Sway default: focus does not follow the mouse
      focus_follows_mouse = "off";
      mouse_follows_focus = "off";
      mouse_modifier = "cmd";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "swap";
    };

    extraConfig = ''
      # Float the applications that tile badly
      yabai -m rule --add app="^System Settings$" manage=off
      yabai -m rule --add app="^System Preferences$" manage=off
      yabai -m rule --add app="^Calculator$" manage=off
      yabai -m rule --add app="^Karabiner" manage=off
      yabai -m rule --add app="^Archive Utility$" manage=off
      yabai -m rule --add app="^Activity Monitor$" manage=off
      yabai -m rule --add app="^System Information$" manage=off
      yabai -m rule --add app="^Finder$" title="(Co(py|nnect)|Move|Info|Pref)" manage=off
      yabai -m rule --add app="^Alfred" manage=off
      yabai -m rule --add app="^Spotlight$" manage=off

      # Focus something sensible when the focused window goes away
      yabai -m signal --add event=window_destroyed \
        action="yabai -m query --windows --window &> /dev/null || yabai -m window --focus recent || yabai -m window --focus first"
      yabai -m signal --add event=window_minimized \
        action="yabai -m query --windows --window &> /dev/null || yabai -m window --focus recent || yabai -m window --focus first"
    '';
  };

  # The skhd module sets KeepAlive but leaves RunAtLoad unset. KeepAlive alone
  # does get the job started, but state it outright — starting at login is the
  # entire point of moving these off the hand-run LaunchAgents.
  launchd.user.agents.skhd.serviceConfig.RunAtLoad = true;

  # Persist agent output for diagnosing launch failures.
  launchd.user.agents.yabai.serviceConfig = {
    StandardOutPath = "/tmp/yabai.out.log";
    StandardErrorPath = "/tmp/yabai.err.log";
    ProgramArguments = lib.mkForce
      (waitThenExec "${yabaiCfg.package}/bin/yabai" ''-c "${yabaiConfigFile}"'');
  };
  launchd.user.agents.skhd.serviceConfig = {
    StandardOutPath = "/tmp/skhd.out.log";
    StandardErrorPath = "/tmp/skhd.err.log";
    # /etc/skhdrc is on the root volume, so only the binary needs waiting for.
    ProgramArguments = lib.mkForce
      (waitThenExec "${skhdCfg.package}/bin/skhd" "-c /etc/skhdrc");
  };

  services.skhd = {
    enable = true;

    # cmd stands in for Sway's $mod (Mod4/Super). Keeps the Sway muscle memory
    # where macOS leaves the key free.
    skhdConfig = ''
      # ── Core ────────────────────────────────────────────────────────
      # Terminal (sway: $mod+Return)
      cmd - return : open -na Alacritty

      # Close focused window (sway: $mod+Shift+q)
      cmd + shift - q : yabai -m window --close

      # Reload both services (sway: $mod+Shift+c)
      cmd + shift - c : yabai --restart-service; skhd --reload
      cmd + shift - r : yabai --restart-service

      # ── Focus (sway: $mod+h/j/k/l) ──────────────────────────────────
      # The `|| opposite direction` fallback reproduces Sway's focus wrapping.
      cmd - h : yabai -m window --focus west  || yabai -m window --focus east
      cmd - j : yabai -m window --focus south || yabai -m window --focus north
      cmd - k : yabai -m window --focus north || yabai -m window --focus south
      cmd - l : yabai -m window --focus east  || yabai -m window --focus west

      cmd - left  : yabai -m window --focus west  || yabai -m window --focus east
      cmd - down  : yabai -m window --focus south || yabai -m window --focus north
      cmd - up    : yabai -m window --focus north || yabai -m window --focus south
      cmd - right : yabai -m window --focus east  || yabai -m window --focus west

      # ── Move / swap (sway: $mod+Shift+h/j/k/l) ──────────────────────
      cmd + shift - h : yabai -m window --swap west  || yabai -m window --swap east
      cmd + shift - j : yabai -m window --swap south || yabai -m window --swap north
      cmd + shift - k : yabai -m window --swap north || yabai -m window --swap south
      cmd + shift - l : yabai -m window --swap east  || yabai -m window --swap west

      cmd + shift - left  : yabai -m window --swap west  || yabai -m window --swap east
      cmd + shift - down  : yabai -m window --swap south || yabai -m window --swap north
      cmd + shift - up    : yabai -m window --swap north || yabai -m window --swap south
      cmd + shift - right : yabai -m window --swap east  || yabai -m window --swap west

      # ── Floating (sway: $mod+Shift+o / $mod+o) ──────────────────────
      cmd + shift - o : yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2
      cmd - o : yabai -m window --focus recent

      # ── Layout ──────────────────────────────────────────────────────
      # Toggle split orientation (sway: $mod+e)
      cmd - e : yabai -m window --toggle split
      # Fullscreen
      cmd - g : yabai -m window --toggle zoom-fullscreen
      # Balance the tree
      cmd + shift - b : yabai -m space --balance
      # Focus most recent (sway: $mod+a focus parent has no yabai equivalent)
      cmd - a : yabai -m window --focus recent

      # ── Resize (sway uses a $mod+r resize mode; this is modeless) ────
      cmd + alt - h : yabai -m window --resize left:-50:0   || yabai -m window --resize right:-50:0
      cmd + alt - j : yabai -m window --resize bottom:0:50  || yabai -m window --resize top:0:50
      cmd + alt - k : yabai -m window --resize top:0:-50    || yabai -m window --resize bottom:0:-50
      cmd + alt - l : yabai -m window --resize right:50:0   || yabai -m window --resize left:50:0

      cmd + alt - left  : yabai -m window --resize left:-50:0   || yabai -m window --resize right:-50:0
      cmd + alt - down  : yabai -m window --resize bottom:0:50  || yabai -m window --resize top:0:50
      cmd + alt - up    : yabai -m window --resize top:0:-50    || yabai -m window --resize bottom:0:-50
      cmd + alt - right : yabai -m window --resize right:50:0   || yabai -m window --resize left:50:0

      # ── Displays (sway: $mod+Shift+w moves a workspace to the other output) ──
      cmd + shift - w : yabai -m window --display next || yabai -m window --display first; \
                        yabai -m display --focus next || yabai -m display --focus first
      cmd + ctrl - h : yabai -m display --focus west || yabai -m display --focus east
      cmd + ctrl - l : yabai -m display --focus east || yabai -m display --focus west

      # Use native macOS shortcuts for Spaces; scripting-addition shortcuts stay unbound.
    '';
  };
}
