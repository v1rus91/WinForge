# Changelog

## 1.2.1 — 2026-09-07
- Fix: Persist watchdog now runs as the interactive user (elevated) instead of SYSTEM, so HKCU tweaks are re-applied to the right profile.
- Fix: reverting a journal that touched the Default-user hive mounts/unmounts the hive.
- GUI: hovering a tweak card shows the exact registry keys, services, tasks and commands it will run.

## 1.2.0 — 2026-09-07
- New profile **gaming-laptop** (47 tweaks) and two laptop tweaks: AC-only gaming power settings
  (PCIe ASPM, boost Aggressive, USB suspend, Wi-Fi max performance) and adaptive brightness off (power plan + Intel CABC).
- `gaming.nic-power-off` is no longer tagged recommended (battery cost), so Balanced/Laptop profiles skip it.

## 1.1.0 — 2026-09-07
- 11 new desktop-gaming tweaks: global 0.5 ms timer, memory compression/page combining off + DisablePagingExecutive,
  NIC power saving off, mouse/keyboard queue size, audio ducking off, low-impact Defender scans, QoS reserve 0,
  desktop power pack (PCIe ASPM, USB3 LPM, disk sleep, CPU min 100 %, boost Aggressive), and advanced: GPU MSI mode,
  NIC interrupt moderation/flow control/EEE off, hypervisor off.
- Windowed-game optimisations now also enable Variable Refresh Rate.
- New profile **gaming-desktop** (52 tweaks).

## 1.0.0 — 2026-09-07
- Initial release: 145 declarative tweaks in 14 categories, 6 profiles, journaled undo, live state detection,
  WinForge Score, WPF GUI, console TUI, silent CLI, Persist watchdog, cleaner, app remover, EN/UK localisation.
