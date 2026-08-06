{ config, pkgs, ... }:

# yabai + skhd, managed as launchd agents so they start at login.
#
# Previously these were started by hand. Three competing LaunchAgents had
# accumulated in ~/Library/LaunchAgents — com.koekeishiya.yabai (pointing at a
# manually installed ~/.local/bin/yabai, never loaded), com.jackielii.skhd and
# homebrew.mxcl.skhd-zig (both loaded, both trying to own skhd). Those must be
# removed, or they will fight with the agents nix-darwin installs; see the
# activation notes in the README.
#
# ── Accessibility permission ───────────────────────────────────────────
# macOS gates window management behind Accessibility, granted per binary path.
# Because Nix store paths change on every version bump, the grant is invalidated
# whenever yabai or skhd is updated, and both must be re-approved under
# System Settings → Privacy & Security → Accessibility. That is the standing
# cost of managing them with Nix rather than Homebrew; the payoff is that they
# actually start on boot.

let
  theme = import ../../home/colors.nix;
  opacity = theme.opacity;
in {
  # ── Code signing ───────────────────────────────────────────────────
  # On Apple Silicon the linker ad-hoc signs every binary it produces, leaving
  # the signature flagged `linker-signed` (0x20002). macOS will not persist a
  # TCC grant for a linker-signed executable: the process asks for
  # Accessibility, is refused, and never appears in the Privacy & Security list
  # with a toggle at all — so there is no way to approve it. With KeepAlive set
  # the agent then relaunches every ten seconds, asks again, and exits again.
  #
  # Re-signing with a plain ad-hoc signature clears the flag (0x20002 → 0x2)
  # and the binaries become grantable. This is done at build time with
  # nixpkgs' sigtool, verified to produce flags=0x2(adhoc).
  #
  # Note the grant is keyed to the binary's code hash, so updating yabai or
  # skhd will require re-approving them in System Settings.
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

    # The scripting addition is what yabai needs for Spaces manipulation
    # (moving windows between Spaces, instant Space switching). It requires
    # SIP to be partially disabled and does not work on macOS 26 at all, so
    # it stays off and the Space bindings below are absent as a result.
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

      # ── Spaces ──────────────────────────────────────────────────────
      # Deliberately unbound. Switching Spaces and moving windows between them
      # both need the scripting addition, which is unavailable on macOS 26.
      # Use the native Ctrl+1..9 shortcuts instead (System Settings → Keyboard
      # → Keyboard Shortcuts → Mission Control), which work because
      # dock.mru-spaces = false pins the Space order.
    '';
  };
}
