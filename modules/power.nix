{ ... }:

# Power management for the laptop.
#
# Nothing in here lowers a ceiling. Boost stays on, the maximum frequency is
# untouched, the firmware's power limits are left alone and the Wi-Fi radio
# keeps running at full power. What it reclaims is hardware that was never
# asked to do anything: before this file existed every PCIe device on the
# machine sat pinned at runtime-PM "on", including the Ethernet controller
# with no cable in it and the NVMe between reads.
#
# `powertop --auto-tune` sets most of the same bits, and NixOS will even run it
# at boot via powerManagement.powertop.enable. It is the wrong shape for this:
# a one-shot imperative sweep with no notion of AC versus battery, which also
# autosuspends every input device it can find. TLP is the declarative version
# that knows the difference between the two power sources.

{
  # TLP and power-profiles-daemon both want to own EPP, the platform profile
  # and the governor. Nothing here enables ppd, but desktop modules pull it in
  # as a default, so this turns the conflict into an evaluation error instead
  # of two daemons overwriting each other at runtime.
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # ── CPU ───────────────────────────────────────────────────────────
      # amd-pstate is already the active driver in EPP mode -- the kernel
      # picks it on Zen 2 and later, so this is not the thing to "fix". That
      # also makes the governor the uninteresting knob here: under
      # amd-pstate-epp, "powersave" IS the ordinary dynamic governor and
      # "performance" pins every core to its maximum clock forever. Keeping
      # the dynamic one on both sides is what leaves the full range available.
      #
      # The energy/performance hint is the real setting, and it changes how
      # eagerly the CPU ramps up -- not how far it can go. On battery a burst
      # of work still gets the entire chip, it just stops holding cores at
      # high clocks in anticipation of work that never arrives.
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;

      # The ThinkPad firmware profile is deliberately not set. Its "low-power"
      # setting is the one knob in reach that genuinely costs performance:
      # it lowers the SoC's sustained power limits, so a long compile gets
      # slower rather than merely lazier to start. Left at the firmware's
      # "balanced" on both sources. Uncomment to trade that away:
      #   PLATFORM_PROFILE_ON_BAT = "low-power";

      # ── PCIe ──────────────────────────────────────────────────────────
      # This is where the free watts are. "auto" lets a device nothing is
      # talking to drop into D3; it costs microseconds of wake latency on the
      # next access and no throughput at all.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";

      # ASPM is left at the firmware's choice. Forcing "powersupersave" is
      # worth something on this platform, but the RTL8822CE has a long history
      # of answering ASPM L1 with latency spikes and throughput collapse, and
      # a Wi-Fi link that works perfectly is worth more than the watt. See the
      # note at the bottom of this file for how to try it anyway.

      # ── Wi-Fi ─────────────────────────────────────────────────────────
      # Radio power saving stays off on both sources. This is the setting that
      # shows up as latency spikes on an otherwise idle link, and TLP would
      # otherwise switch it on for battery. The card still gets runtime PM
      # above, which only ever acts while the interface is down.
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

      # ── Audio ─────────────────────────────────────────────────────────
      # powertop showed the Realtek codec at 100% residency: PipeWire holds
      # the device open, so it never reaches the idle timeout on its own.
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # ── USB ───────────────────────────────────────────────────────────
      # The usual reason to be careful with USB autosuspend is a HID device
      # that suspends and then swallows the keypress meant to wake it. Not a
      # risk here: powertop identifies the built-in keyboard and touchpad as
      # "PS/2 Touchpad / Keyboard / Mouse", so they are not on this bus at all.
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

  # ── If you want to try ASPM later ───────────────────────────────────
  # Add both of these together, never the first on its own:
  #
  #   services.tlp.settings.PCIE_ASPM_ON_BAT = "powersupersave";
  #   boot.extraModprobeConfig = "options rtw88_pci disable_aspm=1";
  #
  # Then live on it for a few days on battery and watch for the specific
  # failure mode -- ping times to the router growing tails, throughput falling
  # off after the link has been idle. `ping -i 0.2 <gateway>` for a minute is
  # usually enough to see it. If it appears, remove both lines again; the
  # module option is only a hint to the driver and does not reliably override
  # a global policy of powersupersave.
}
