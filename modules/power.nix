{ ... }:

# Laptop power management. Keep boost available while allowing idle devices
# to suspend; Wi-Fi power saving stays disabled to avoid latency spikes.

{
  # TLP owns the CPU power policy; do not run power-profiles-daemon alongside it.
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # With amd-pstate-epp, powersave allows dynamic scaling. EPP controls ramp-up
      # policy, while boost remains enabled on both power sources.
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;

      # Leave the firmware platform profile unchanged to retain sustained power limits.

      # Allow idle PCIe devices to runtime-suspend.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";

      # Leave ASPM at the firmware default to avoid RTL8822CE latency regressions.

      # Disable Wi-Fi radio power saving on both power sources.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

      # ── Audio ─────────────────────────────────────────────────────────
      # powertop showed the Realtek codec at 100% residency: PipeWire holds
      # the device open, so it never reaches the idle timeout on its own.
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # The built-in keyboard and touchpad use PS/2, so USB autosuspend excludes them.
      USB_AUTOSUSPEND = 1;
    };
  };

  # ── The settings TLP does not cover ─────────────────────────────────
  # Both of these come from powertop's own "Software Settings in Need of
  # Tuning" list.

  # Batch writeback so the NVMe and the CPU wake up together every 15 seconds
  # instead of every 5. What is traded is up to ten extra seconds of dirty
  # page cache at the moment of a hard power loss.
  boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 1500;

  # The NMI watchdog catches kernel lockups by arming a performance-counter
  # interrupt on every core, forever. That is a permanent wakeup source in
  # exchange for a diagnostic nobody is reading on a laptop.
  boot.kernel.sysctl."kernel.nmi_watchdog" = 0;

}
