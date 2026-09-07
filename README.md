<div align="center">

# ⚒️ WinForge

**A Windows 11 optimizer that knows exactly what it changed — and can undo it.**

[![CI](https://img.shields.io/github/actions/workflow/status/v1rus91/WinForge/ci.yml?branch=main&label=CI)](.github/workflows/ci.yml)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-blue)
![Windows 11 22H2–25H2](https://img.shields.io/badge/Windows%2011-22H2%20→%2025H2-0078D4)
![145 tweaks](https://img.shields.io/badge/tweaks-145-brightgreen)
![License MIT](https://img.shields.io/badge/license-MIT-lightgrey)

Privacy · AI/Copilot/Recall · Bloatware · Performance · Gaming · Services · UI · Explorer · Edge · Updates · Network · Security · Power

</div>

---

## Why another optimizer?

I studied the four most popular open-source tools — [Win11Debloat](https://github.com/Raphire/Win11Debloat), [Sparkle](https://github.com/thedogecraft/sparkle), [RyTuneX](https://github.com/rayenghanmi/RyTuneX) and [GTweak](https://github.com/Greedeks/GTweak) — and took the best idea from each while fixing what they all get wrong:

| Problem in existing tools | WinForge |
|---|---|
| "Undo" writes hard-coded defaults, not what *you* had (Sparkle, RyTuneX) | Every primitive records the **previous value** into a journal; revert restores *your* state |
| Toggle state = what the app remembers, not what the OS says (Sparkle) | **Live state detection** on every launch: registry / service / task / appx / feature / hosts / bcdedit are probed |
| No build gating — 25H2 keys on 22H2 machines, Win10 keys on 24H2 (Sparkle, RyTuneX) | Every tweak carries `minBuild` / `editions`; inapplicable ones are greyed out and skipped |
| Dangerous defaults (kill Defender, delete DLLs, rename system EXEs, `vssadmin delete shadows /all`) | Three risk tiers; **advanced** tweaks are never in a profile, never in the score, always explicit |
| Tweaks reset after a feature update and nobody notices | **Persist watchdog** re-applies drifted tweaks 2 min after logon |
| Logic buried in a 3 000-line C# file or 90 dot-sourced scripts | **145 tweaks are plain JSON** — readable, diffable, testable, auditable |
| Windows only, no CI | Cross-platform Pester suite + PSScriptAnalyzer + Win/Linux CI |

## Features

- **145 declarative tweaks** in 14 categories with EN/UK descriptions, risk level, tags, reboot flags, build gates.
- **Journaled undo.** `-RevertJournal last` puts things back exactly. Per-tweak revert too.
- **WinForge Score** — three live gauges (Privacy / Performance / Clean) computed from real system state.
- **6 profiles**: Balanced ★, Privacy Max, Gaming, Minimal/Debloat, Developer, Laptop/Battery. Export your own selection as a profile and share it.
- **Three front-ends**: dark WPF GUI (never freezes — work runs in a background runspace), console TUI, and a fully silent CLI for deployment scripts.
- **Dry run** for everything, restore point before every session, per-session logs.
- **App remover** with the full installed/provisioned inventory and "known bloat" markers.
- **Cleaner** for temp, caches, update leftovers, crash dumps, DO cache, WER, Recycle Bin — sizes shown before you delete.
- **Default-user / sysprep mode** writes user tweaks into the Default profile hive for new accounts.
- **24H2 / 25H2 aware**: Recall, Click to Do, AI agents & connectors, Windows Intelligence, AI Fabric service, Input Insights, Gaming Copilot, drag-tray, category Start menu, BitLocker auto-encryption, RDP-file warning.
- Runs on Windows PowerShell 5.1 (ships with Windows) — no runtime, no installer, no compiler. Works from pwsh 7 too.

## Quick start

```powershell
# 1. one-liner (elevated PowerShell)
irm https://raw.githubusercontent.com/v1rus91/WinForge/main/get.ps1 | iex

# 2. or clone / download the zip and run
.\WinForge.ps1                 # GUI (asks for UAC)
.\WinForge.ps1 -Cli            # console menu
```

### CLI cheat-sheet

```powershell
.\WinForge.ps1 -Status                                   # hardware, build, live score
.\WinForge.ps1 -List -Category ai                        # what is available for this build
.\WinForge.ps1 -Profile gaming -DryRun                   # preview: nothing is changed
.\WinForge.ps1 -Profile balanced -Silent -Persist on     # unattended + watchdog
.\WinForge.ps1 -Apply privacy.telemetry,ai.*,category:edge,tag:recommended
.\WinForge.ps1 -Apply bloat.ms-junk -DefaultUser         # also for future accounts
.\WinForge.ps1 -Revert ai.copilot                        # one tweak back
.\WinForge.ps1 -RevertJournal last                       # whole last session back
.\WinForge.ps1 -Profile privacy -Export my.json          # save selection as a profile
.\WinForge.ps1 -Import my.json -Silent
.\WinForge.ps1 -Cleanup
.\WinForge.ps1 -Validate                                 # catalog + profiles schema check (CI)
```

Selectors accepted by `-Apply` / `-Revert` and in profile files: exact id, wildcard (`ai.*`), `category:<name>`, `tag:<name>`, `risk:<safe|moderate|advanced>`.

## Profiles

| Profile | Tweaks | What it is for |
|---|---|---|
| ⚖️ **balanced** | 25 | Everything tagged ★ recommended. Zero functionality loss. The one-click default. |
| 🔒 **privacy** | 38 | Max privacy: all privacy/AI/Edge tweaks, hosts block, local search, Quad9 DoH, no cloud sync. |
| 🎮 **gaming** | 40 | Balanced + DVR off, HAGS, windowed optimisations, raw mouse, MMCSS, Ultimate plan, no WU drivers, TCP tuning. Keeps Xbox services. |
| 🧹 **minimal** | 39 | Strip it down: every bloat set, services to manual, indexer off. |
| 💻 **developer** | 35 | Balanced + dev mode, long paths, WSL2, Sandbox, verbose boot, extensions, classic menu. |
| 🔋 **laptop** | 30 | Balanced + battery-friendly bits. Never touches throttling or the Ultimate plan. |

Full catalog with every registry key, service and task: **[docs/TWEAKS.md](docs/TWEAKS.md)**.

## How a tweak looks

```json
{
  "id": "ai.recall",
  "name": { "en": "Disable Windows Recall & snapshot saving", "uk": "Вимкнути Windows Recall і збереження знімків" },
  "description": { "en": "…", "uk": "…" },
  "risk": "safe", "weight": 3, "tags": ["ai", "recommended"], "minBuild": 26100, "defaultUser": true,
  "actions": [
    { "type": "registry", "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI", "name": "AllowRecallEnablement", "value": 0 },
    { "type": "task", "path": "\\Microsoft\\Windows\\WindowsAI\\Recall\\", "name": "PolicyConfiguration" },
    { "type": "feature", "name": "Recall", "state": "Disabled" }
  ],
  "detect": [ { "type": "registry", "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI", "name": "AllowRecallEnablement", "value": 0 } ]
}
```

Action types: `registry`, `registryDelete`, `registryDeleteKey`, `service`, `task`, `appx`, `feature`, `capability`, `command`, `powershell`.
Every action except `command`/`powershell` is journaled automatically; those two take an explicit `revert`.
Optional `detect` overrides state probing (`registryMatch`, `registryGreater`, `fileContains`, `fileMissing`, `commandMatch` are extra detect-only types).

Adding a tweak = adding a JSON object. `./WinForge.ps1 -Validate` and the Pester suite will tell you if you got the schema wrong.

## Architecture

```
WinForge.ps1              entry: elevation, CLI parsing, dispatch to GUI / TUI / silent
src/WinForge.Core.psm1    primitives with journaling: registry, service, task, appx, feature, command; restore points; default-user hive
src/WinForge.Catalog.psm1 JSON catalog loader, schema validation, applicability, state detection, apply/revert, profiles, i18n
src/WinForge.Session.psm1 one journaled session: restore point → tweaks → explorer restart → summary
src/WinForge.Diagnostics  hardware/OS inventory, runtime stats, WinForge Score, cleaner
src/WinForge.Gui.ps1      WPF, background runspace worker, dispatcher timer
src/WinForge.Tui.ps1      console menu
src/WinForge.Persist.ps1  logon watchdog (scheduled task) that re-applies drifted tweaks
catalog/*.json            14 category files, 145 tweaks
profiles/*.json           6 profiles (+ yours)
tests/                    Pester (runs on Linux/macOS too)
tools/                    Build-Docs, Invoke-Lint, Invoke-Tests
```

Data lives in `%ProgramData%\WinForge\` — `logs\`, `journal\` (one JSON per session), `backup\` (.reg exports of deleted keys), `config.json`, `persist.json`.

## Safety model

1. A restore point is created before every session (the 24-hour Windows cooldown is lifted).
2. Every registry/service/task/feature change records its previous value; deleted keys are exported to `.reg` first.
3. **safe** — no functionality loss, ★ ones form the Balanced profile. **moderate** — trade-off stated in the description. **advanced** — security or stability trade-off (VBS off, Spectre mitigations off, IFEO, hosts, dynamic tick, Edge removal). Advanced tweaks never appear in profiles or in the score.
4. Package removal is marked `reversible: false`; the GUI shows it, the journal still tries a manifest re-register on revert.
5. WinForge never disables Defender, never deletes system DLLs or CBS packages, never touches Windows Update servicing binaries. Those "tricks" break SFC/Windows Update and are deliberately absent.

## Development

```powershell
Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser
./tools/Invoke-Tests.ps1      # 33 tests, cross-platform
./tools/Invoke-Lint.ps1
./tools/Build-Docs.ps1        # regenerate docs/TWEAKS.md
./WinForge.ps1 -Profile balanced -DryRun -Silent   # on Windows
```

## Credits

Tweak research: Win11Debloat (Raphire), Sparkle (thedogecraft / Parcoil), RyTuneX (rayenghanmi), GTweak (Greedeks), Chris Titus WinUtil. WinForge shares no code with them; the catalog was re-derived key by key and gated per Windows build.

## License

MIT
