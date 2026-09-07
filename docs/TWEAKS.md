# WinForge tweak catalog

_Generated 2026-09-07 from catalog/*.json — 156 tweaks. Do not edit by hand._

Legend: **safe** = no functionality loss · **moderate** = read the description · **advanced** = opt-in, never part of a profile, never counted in the score. `⟳` needs reboot · `✖` not reversible (package removal) · `build N+` minimum Windows build.

## 🔒 privacy (16)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `privacy.telemetry` | **Disable telemetry & diagnostic data**<br><sub>Sets diagnostic data to Security level via policy, disables DiagTrack service, autologger, and the compatibility/CEIP scheduled tasks.</sub> | safe | ★ | 6× registry, 3× service, 14× task |
| `privacy.advertising-id` | **Disable advertising ID & tailored experiences**<br><sub>Stops apps from using your advertising ID and Windows from using diagnostic data for tailored tips and ads.</sub> | safe | ★ | 5× registry |
| `privacy.activity-history` | **Disable activity history & timeline upload**<br><sub>Windows stops collecting your app/document activity and publishing it to Microsoft.</sub> | safe |  | 4× registry |
| `privacy.input-personalization` | **Disable typing/inking data collection & online speech**<br><sub>Stops harvesting of typing, handwriting and contacts for personalization; disables cloud speech recognition consent.</sub> | safe |  | 8× registry |
| `privacy.feedback` | **Disable feedback requests**<br><sub>Windows will never ask 'How likely are you to recommend...'.</sub> | safe |  | 1× registry, 1× registryDelete |
| `privacy.error-reporting` | **Disable Windows Error Reporting**<br><sub>No crash reports are sent to Microsoft; the WER service is disabled.</sub> | safe |  | 4× registry, 2× service |
| `privacy.location` | **Disable location services & Find My Device**<br><sub>Turns off location access for the system and apps, the geolocation service and Find My Device.</sub> | moderate |  | 4× registry, 1× service |
| `privacy.app-permissions` | **Deny background app access to camera/mic/contacts/etc. (system-wide)**<br><sub>Sets ConsentStore defaults to Deny for account info, contacts, calendar, call history, email, tasks, messaging, radios, app diagnostics and documents. Camera and microphone are left as-is.</sub> | moderate |  | 10× registry |
| `privacy.wifi-sense` | **Disable Wi-Fi Sense hotspot sharing**<br><sub>Prevents automatic connection to suggested open hotspots and hotspot reporting.</sub> | safe |  | 2× registry |
| `privacy.cloud-clipboard-sync` | **Disable clipboard & settings sync to the cloud**<br><sub>Clipboard history stays local; Windows settings sync to Microsoft account is disabled.</sub> | moderate |  | 4× registry |
| `privacy.app-launch-tracking` | **Disable app launch tracking & inventory**<br><sub>Application Compatibility inventory and telemetry agents (AIT) are turned off.</sub> | safe |  | 4× registry |
| `privacy.experiments` | **Disable Windows experiments & CEIP**<br><sub>Opts out of Microsoft experimentation rollouts and the Customer Experience Improvement Program.</sub> | safe |  | 3× registry |
| `privacy.speech-model-updates` | **Disable automatic speech model downloads**<br><sub>Stops Windows from silently downloading updated speech recognition models.</sub> | safe |  | 1× registry |
| `privacy.cdp-user-service` | **Disable Connected Devices Platform user service (CDPUserSvc)**<br><sub>Cross-device 'continue on PC' plumbing that phones home. Breaks Phone Link / Nearby Share.</sub> | moderate |  | 1× service |
| `privacy.nvidia-telemetry` | **Disable NVIDIA telemetry**<br><sub>Disables the NvTelemetryContainer service and its scheduled report tasks (only if NVIDIA drivers are installed).</sub> | safe |  | 1× service, 5× task |
| `privacy.telemetry-hosts` | **Block telemetry domains in hosts file**<br><sub>Appends a curated block of Microsoft telemetry endpoints to C:\Windows\System32\drivers\etc\hosts (marked with WinForge tags; removable). Does not touch Windows Update or Store domains.</sub> | advanced |  | 1× powershell |

## 🤖 ai (11)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `ai.copilot` | **Disable Copilot & remove the Copilot app**<br><sub>Policy-disables Windows Copilot, hides the taskbar button, blocks the shell extension and uninstalls the Microsoft.Copilot store package.</sub> | safe | build 22621+ ★ | 4× appx, 4× registry |
| `ai.recall` | **Disable Windows Recall & snapshot saving**<br><sub>Blocks Recall enablement by policy, turns off snapshot saving and AI data analysis, disables Recall scheduled tasks and removes the optional feature.</sub> | safe | build 26100+ ★ | 1× feature, 4× registry, 2× task |
| `ai.click-to-do` | **Disable Click to Do**<br><sub>Turns off the on-screen AI action overlay (Win+Click) on Copilot+ PCs.</sub> | safe | build 26100+ | 2× registry |
| `ai.agents-connectors` | **Disable AI agents, connectors & Windows Intelligence**<br><sub>25H2 agentic features: blocks agent connectors, AI data collection, Settings 'AI components' page and the Windows Intelligence policy.</sub> | safe | build 26100+ | 5× registry |
| `ai.fabric-service` | **Disable AI Fabric service (WSAIFabricSvc) autostart**<br><sub>Sets the Windows AI Fabric service to Manual so it does not run at boot unless something requests it.</sub> | safe | build 26100+ | 2× service, 2× task |
| `ai.paint` | **Disable AI features in Paint**<br><sub>Cocreator, Image Creator, Generative Fill/Erase and Remove Background are hidden.</sub> | safe | build 22621+ | 5× registry |
| `ai.notepad` | **Disable AI features in Notepad**<br><sub>Removes the Rewrite/Summarize Copilot button from Notepad.</sub> | safe | build 22621+ | 2× registry |
| `ai.edge-copilot` | **Disable Copilot & AI in Microsoft Edge**<br><sub>Removes the Copilot sidebar, page-context sharing, AI history search, Compose and Bing Chat on the new tab page.</sub> | safe |  | 8× registry |
| `ai.gaming-copilot` | **Disable Gaming Copilot in Game Bar**<br><sub>Removes the Copilot widget from the Xbox Game Bar overlay.</sub> | safe | build 26100+ | 1× registry |
| `ai.input-insights` | **Disable Input Insights (typing telemetry for AI)**<br><sub>Disables the InputInsights scheduled task and the text-input insights setting.</sub> | safe | build 26100+ | 1× registry, 1× task |
| `ai.settings-pages` | **Hide 'AI components' & 'App actions' in Settings**<br><sub>Adds hide:aicomponents;appactions to the Settings page visibility policy.</sub> | moderate | build 26100+ | 1× powershell |

## 🧹 bloatware (10)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `bloat.ms-junk` | **Remove Microsoft junk apps (safe set)**<br><sub>Bing News/Weather/Finance/Sports, Solitaire, Get Help, Get Started, Feedback Hub, Maps, Office Hub, Power Automate, Todo, Clipchamp, Journal, Dev Home, PC Manager, Family, Quick Assist, People, Mail & Calendar legacy, Sway, OneNote store, 3D Viewer/Print 3D, Mixed Reality, Skype, Cortana.</sub> | safe | ✖ ★ | 44× appx |
| `bloat.third-party` | **Remove third-party sponsored apps**<br><sub>Candy Crush, Spotify stub, TikTok, Netflix, Disney+, Prime Video, Facebook/Instagram, LinkedIn, Duolingo, Hulu, Twitter, WhatsApp stub, Amazon and other OEM/Store promo packages.</sub> | safe | ✖ ★ | 45× appx |
| `bloat.oem` | **Remove OEM helper apps (HP, Dell, Lenovo, LG)**<br><sub>Removes vendor store apps like HP Support Assistant, Dell Digital Delivery, Lenovo Vantage, LG Monitor app. Vendor Win32 utilities are untouched.</sub> | moderate | ✖ | 5× appx |
| `bloat.xbox` | **Remove Xbox apps & Game Bar**<br><sub>Xbox app, Game Bar overlay, Xbox TCUI/Identity/Speech overlays. Do NOT use if you play Game Pass PC titles or use Game Bar recording.</sub> | moderate | ✖ | 7× appx |
| `bloat.teams-outlook` | **Remove Teams (consumer) & new Outlook**<br><sub>Removes the personal Teams client and the pre-installed 'Outlook (new)'.</sub> | safe | ✖ | 3× appx |
| `bloat.widgets` | **Remove Widgets (Web Experience Pack)**<br><sub>Uninstalls the Widgets platform and the news feed behind it, and hides the taskbar button.</sub> | safe | ✖ ★ | 2× appx, 1× powershell, 2× registry |
| `bloat.cross-device` | **Remove Cross Device Experience Host & Phone Link**<br><sub>Removes the Phone Link app and the cross-device host used for mobile mirroring.</sub> | moderate | ✖ | 2× appx, 1× registry |
| `bloat.onedrive` | **Uninstall OneDrive**<br><sub>Runs the OneDrive uninstaller, removes the Explorer sidebar entry, autorun and default-user setup hook. Files in the OneDrive folder are kept.</sub> | moderate | ✖ | 3× powershell, 2× registry, 1× registryDelete |
| `bloat.optional-apps` | **Remove rarely used inbox apps (Camera, Alarms, Media Player, Sound Recorder…)**<br><sub>Camera, Alarms & Clock, Media Player, Voice Recorder, Sticky Notes, Whiteboard, Paint 3D. Calculator, Photos, Notepad, Paint, Snipping Tool and Terminal are kept.</sub> | moderate | ✖ | 7× appx |
| `bloat.consumer-features` | **Stop Windows from auto-installing promoted apps**<br><sub>Disables Content Delivery Manager silent installs, pre-installed app re-provisioning, Start suggestions and 'consumer features'.</sub> | safe | ★ | 21× registry |

## ⚡ performance (16)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `perf.visual-effects` | **Reduce animations & visual effects (keep font smoothing)**<br><sub>Turns off window/menu animations, fade effects and shadows while keeping ClearType and thumbnails. Big win on integrated GPUs and remote sessions.</sub> | safe | ⟳ | 7× registry |
| `perf.menu-delay` | **Instant menus & hover (MenuShowDelay 0)**<br><sub>Removes the 400 ms delay before submenus and tooltips open.</sub> | safe |  | 2× registry |
| `perf.foreground-priority` | **Prioritise foreground apps (Win32PrioritySeparation)**<br><sub>Sets the scheduler to short, variable quanta with a 3:1 foreground boost (value 38 / 0x26), the classic desktop responsiveness setting.</sub> | safe |  | 1× registry |
| `perf.multimedia-profile` | **Multimedia scheduler: no network throttling, max responsiveness**<br><sub>NetworkThrottlingIndex = off, SystemResponsiveness = 10 (reserves less CPU for background), Games task gets High scheduling/GPU priority.</sub> | safe | ★ | 6× registry |
| `perf.svchost-split` | **Group svchost processes by RAM size**<br><sub>Raises SvcHostSplitThresholdInKB to your installed RAM so Windows merges dozens of svchost.exe processes into fewer hosts (fewer context switches, less RAM).</sub> | safe | ⟳ | 1× powershell |
| `perf.startup-delay` | **Remove startup app delay**<br><sub>Windows waits ~10 s after logon before launching startup apps; this removes that wait.</sub> | safe |  | 1× registry |
| `perf.app-timeouts` | **Faster shutdown & hung-app timeouts**<br><sub>WaitToKillServiceTimeout 2 s, HungAppTimeout 1 s, AutoEndTasks on. Shutdown no longer waits 20 s for stuck apps.</sub> | safe |  | 4× registry |
| `perf.ntfs` | **NTFS: disable last-access timestamps & 8.3 names**<br><sub>Fewer metadata writes on every file read; 8.3 short-name generation off for new volumes.</sub> | safe |  | 2× registry |
| `perf.background-apps` | **Stop Store apps running in the background**<br><sub>Global 'let apps run in background' off. Notifications from those apps may be delayed.</sub> | safe |  | 2× registry |
| `perf.sysmain` | **Disable SysMain (Superfetch) on SSD systems**<br><sub>Prefetch/Superfetch gives nothing on NVMe/SSD and causes disk activity spikes. Keep enabled on HDD.</sub> | moderate |  | 2× registry, 1× service |
| `perf.search-indexer` | **Disable Windows Search indexer**<br><sub>Stops SearchIndexer.exe. Start-menu search still works for apps/settings; file content search becomes slower.</sub> | moderate |  | 1× service |
| `perf.power-throttling-off` | **Disable Power Throttling**<br><sub>Prevents Windows from forcing background processes into low-power CPU states. Better consistency on desktops; hurts laptop battery.</sub> | moderate |  | 1× registry |
| `perf.large-system-cache` | **Prefer larger file-system cache**<br><sub>LargeSystemCache=1: the kernel keeps more file data cached in RAM. Useful with 16 GB+.</sub> | moderate | ⟳ | 1× registry |
| `perf.storage-sense-off` | **Disable Storage Sense auto-cleanup**<br><sub>Stops Windows from deleting Downloads/Recycle Bin items on a schedule without asking.</sub> | safe |  | 1× registry |
| `perf.reserved-storage-off` | **Disable Reserved Storage (~7 GB)**<br><sub>Frees the space Windows holds back for updates. Updates still work but may need free space at install time.</sub> | moderate |  | 1× command, 1× registry |
| `perf.ifeo-telemetry-killers` | **Neutralise CompatTelRunner / DeviceCensus via IFEO**<br><sub>Image File Execution Options 'Debugger' redirects telemetry runners to taskkill so they exit instantly even if a task re-enables them.</sub> | advanced |  | 4× registry |

## 🎮 gaming (21)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `gaming.game-mode` | **Enable Game Mode**<br><sub>Windows prioritises the game and pauses Windows Update driver installs/notifications while playing.</sub> | safe |  | 2× registry |
| `gaming.hags` | **Enable Hardware-Accelerated GPU Scheduling**<br><sub>GPU manages its own VRAM scheduling; lowers latency on modern NVIDIA/AMD/Intel Arc drivers. Required for DLSS 3 frame generation.</sub> | safe | ⟳ | 1× registry |
| `gaming.windowed-optimizations` | **Enable optimisations for windowed games + Variable Refresh Rate**<br><sub>Flip-model swap-effect upgrade for DX10/11 windowed and borderless games plus the Windows VRR toggle (G-Sync/FreeSync in windowed mode): lower latency, Auto HDR support.</sub> | safe |  | 1× registry |
| `gaming.game-dvr-off` | **Disable Game DVR background recording**<br><sub>Turns off the always-on 'record last 30 seconds' capture that costs 5-10 % FPS. Game Bar itself keeps working.</sub> | safe | ★ | 4× registry |
| `gaming.gamebar-popups` | **Silence Game Bar popups (ms-gamebar handler)**<br><sub>Fixes the 'You'll need a new app to open this ms-gamebar' dialog after removing Xbox apps, and stops Game Bar from opening on Win+G.</sub> | safe |  | 8× registry |
| `gaming.fullscreen-optimizations-off` | **Disable Fullscreen Optimizations globally**<br><sub>Forces true exclusive fullscreen behaviour for legacy games; can reduce stutter in some DX9/11 titles.</sub> | moderate |  | 4× registry |
| `gaming.mouse-acceleration-off` | **Disable mouse acceleration (Enhance pointer precision)**<br><sub>1:1 raw mouse movement. Essential for FPS aiming consistency.</sub> | safe | ⟳ | 3× registry |
| `gaming.keyboard-repeat` | **Fastest keyboard repeat rate & shortest delay**<br><sub>KeyboardDelay 0, KeyboardSpeed 31.</sub> | safe | ⟳ | 2× registry |
| `gaming.sticky-keys-off` | **Disable Sticky/Filter/Toggle Keys shortcuts**<br><sub>No more Sticky Keys popup after pressing Shift 5 times mid-game.</sub> | safe |  | 3× registry |
| `gaming.mpo-off` | **Disable Multi-Plane Overlay (fixes flicker/stutter)**<br><sub>Recommended by NVIDIA/AMD for black-screen flicker, stutter and G-Sync issues in windowed games on some GPUs.</sub> | moderate | ⟳ | 1× registry |
| `gaming.gpu-pstate` | **GPU: disable dynamic P-states (NVIDIA/AMD)**<br><sub>Keeps the GPU from dropping clocks mid-frame. Writes DisableDynamicPstate / EnableULPS to every display-class driver key. Higher idle power draw.</sub> | advanced | ⟳ | 1× powershell |
| `gaming.dynamic-tick-off` | **Disable dynamic tick & platform clock (bcdedit)**<br><sub>Legacy timer tweak for frame-time consistency. Can hurt laptops and some 24H2 systems; test before keeping.</sub> | advanced | ⟳ | 2× command |
| `gaming.timer-resolution` | **Global high-resolution timer (0.5 ms for every app)**<br><sub>Since Windows 10 2004 the timer resolution is per-process and background apps get coarse timers; this restores the global behaviour so games and their launchers/overlays all run on the finest timer. Slightly higher idle power.</sub> | moderate | ⟳ build 22000+ | 1× registry |
| `gaming.memory-tuning` | **Memory: no compression/page combining, kernel stays in RAM**<br><sub>Disables memory compression and page combining (spare CPU cycles on 16 GB+ desktops) and sets DisablePagingExecutive so kernel code is never paged out. Not for 8 GB machines.</sub> | moderate | ⟳ | 1× powershell, 1× registry |
| `gaming.nic-power-off` | **Network adapter: disable power saving & 'turn off to save power'**<br><sub>Stops Windows from putting the Ethernet/Wi-Fi adapter into low-power states that cause lag spikes and packet loss after idle. Applied to every connected physical adapter.</sub> | safe | ★ | 1× powershell |
| `gaming.mouse-keyboard-queue` | **Smaller mouse/keyboard driver queues**<br><sub>MouseDataQueueSize / KeyboardDataQueueSize 20 instead of 100: input is flushed to the game sooner under heavy load. Marginal but free; used by most competitive setups.</sub> | moderate | ⟳ | 2× registry |
| `gaming.audio-ducking-off` | **Don't lower game volume when Discord/voice chat is active**<br><sub>Sets the communications 'Do nothing' option so Windows never ducks other audio by 80 % during calls.</sub> | safe | ★ | 1× registry |
| `gaming.defender-low-impact` | **Defender: low-impact scans (20 % CPU cap, only when idle)**<br><sub>Keeps real-time protection but caps scheduled scans at 20 % CPU, runs them only when the PC is idle and skips catch-up quick scans after boot.</sub> | safe | ★ | 1× powershell |
| `gaming.msi-mode-gpu` | **Force MSI interrupt mode on the GPU**<br><sub>Message Signaled Interrupts instead of legacy line-based IRQs for every PCI display adapter: lower DPC latency and fewer micro-stutters on boards where the driver left it off. Reboot required; remove the value to return to the driver default.</sub> | advanced | ⟳ | 1× powershell |
| `gaming.nic-low-latency` | **NIC: interrupt moderation, flow control & EEE off**<br><sub>Advanced adapter properties for lowest packet latency: no interrupt coalescing, no Ethernet flow control, no Energy-Efficient Ethernet. Costs some CPU on 1 Gbps+ downloads. Revert resets the properties to driver defaults.</sub> | advanced |  | 1× powershell |
| `gaming.hypervisor-off` | **Turn off the Hyper-V hypervisor at boot**<br><sub>bcdedit hypervisorlaunchtype off. If VBS/Core Isolation or Hyper-V was active this is the single biggest FPS gain (5-15 %). BREAKS WSL2, Docker Desktop, Windows Sandbox, Hyper-V VMs and Credential Guard until reverted.</sub> | advanced | ⟳ | 1× command |

## ⚙ services (9)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `svc.safe-manual` | **Set rarely needed services to Manual (safe list)**<br><sub>Services start on demand instead of at boot: Fax, Retail Demo, Maps Broker, Parental Controls, Phone, Wallet, Payments/NFC, Windows Insider, Remote Registry, Program Compatibility Assistant, Downloaded Maps, Connected User Experiences helpers.</sub> | safe | ★ | 27× service |
| `svc.diagnostics` | **Disable diagnostic policy & troubleshooting services**<br><sub>DPS, WdiServiceHost, WdiSystemHost, diagnosticshub collector. Built-in troubleshooters stop working until re-enabled.</sub> | moderate |  | 4× service |
| `svc.xbox` | **Disable Xbox Live services**<br><sub>XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, GameInputSvc. Breaks Game Pass / Xbox sign-in.</sub> | moderate |  | 4× service, 1× task |
| `svc.print` | **Disable Print Spooler (no printers)**<br><sub>Also closes the PrintNightmare attack surface. Re-enable before printing or Print-to-PDF.</sub> | moderate |  | 2× service |
| `svc.bluetooth` | **Disable Bluetooth services**<br><sub>bthserv, BTAGService, BluetoothUserService. For desktops with no BT peripherals.</sub> | moderate |  | 3× service |
| `svc.hyperv` | **Disable Hyper-V guest integration services**<br><sub>vmic* services only matter when Windows runs INSIDE a Hyper-V VM. Safe on physical machines.</sub> | safe |  | 8× service |
| `svc.remote-desktop` | **Disable Remote Desktop & Remote Assistance services**<br><sub>TermService, SessionEnv, UmRdpService, RemoteAccess; Remote Assistance policy off.</sub> | moderate |  | 1× registry, 4× service |
| `svc.edge-update` | **Disable Edge & WebView2 background updaters**<br><sub>edgeupdate/edgeupdatem services and the four update scheduled tasks. Edge still updates when launched.</sub> | safe |  | 2× service, 4× task |
| `svc.maintenance-tasks` | **Disable idle maintenance & misc background tasks**<br><sub>Office telemetry, Family Safety, Maps updates, Work Folders, Speech, XblGameSave, Chkdsk proxy, Flighting/Insider tasks, CloudExperienceHost, Windows.old cleanup prompts.</sub> | safe |  | 24× task |

## 🎨 ui (17)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `ui.dark-mode` | **Enable dark mode (system + apps)**<br><sub>Dark theme for shell and applications.</sub> | safe |  | 2× registry |
| `ui.classic-context-menu` | **Restore classic (full) right-click context menu**<br><sub>No more 'Show more options' click. Registers the empty InprocServer32 CLSID override.</sub> | safe | ★ | 1× registry |
| `ui.taskbar-left` | **Align taskbar to the left**<br><sub>Windows 10-style left alignment of Start and pinned icons.</sub> | safe |  | 1× registry |
| `ui.taskbar-search-icon` | **Taskbar search: icon only (no box, no highlights)**<br><sub>Compact search button; disables Search Highlights (Bing trending content) and dynamic content in the search box.</sub> | safe |  | 3× registry |
| `ui.hide-taskview-chat` | **Hide Task View & Chat buttons**<br><sub>Removes the Task View and (on 22H2) Teams Chat buttons from the taskbar. Win+Tab still works.</sub> | safe |  | 2× registry |
| `ui.end-task` | **Add 'End task' to taskbar right-click**<br><sub>Kill hung apps directly from the taskbar without Task Manager.</sub> | safe | build 22631+ ★ | 1× registry |
| `ui.taskbar-seconds` | **Show seconds in the taskbar clock**<br><sub>Classic seconds display. Minor extra CPU wakeups.</sub> | safe | build 22621+ | 1× registry |
| `ui.start-no-recommended` | **Hide 'Recommended' section & account promos in Start**<br><sub>Hides the Recommended feed, Iris ads in Start and Microsoft account notifications; shows more pins.</sub> | safe | ★ | 5× registry |
| `ui.start-allapps-category` | **Start 'All apps' as category grid (25H2)**<br><sub>Uses the new category view instead of the alphabetical list.</sub> | safe | build 26200+ | 1× registry |
| `ui.lockscreen-clean` | **Clean lock screen: no Spotlight tips, fun facts, ads**<br><sub>Keeps your wallpaper but removes overlay text, tips and 'Like what you see'.</sub> | safe |  | 2× registry |
| `ui.desktop-spotlight-off` | **Disable Desktop Spotlight & its desktop icon**<br><sub>Stops the rotating Bing wallpaper feature and removes the 'Learn about this picture' icon.</sub> | safe |  | 2× registry |
| `ui.notifications-quiet` | **Silence Windows tips, suggestions & welcome experience**<br><sub>No 'tips and tricks' toasts, no post-update 'finish setting up' nags, no Suggested notifications, no backup reminders.</sub> | safe | ★ | 6× registry |
| `ui.settings-home-off` | **Hide the Settings 'Home' page (account/365 ads)**<br><sub>Settings opens on System instead of the promotional Home page.</sub> | safe |  | 1× registry |
| `ui.snap-flyouts-off` | **Disable Snap layout flyouts (keep snapping)**<br><sub>No layout popup when hovering maximise or dragging to the top edge.</sub> | safe |  | 2× registry |
| `ui.verbose-logon` | **Verbose boot/logon status messages**<br><sub>Shows what Windows is doing during boot and shutdown instead of 'Please wait'.</sub> | safe |  | 1× registry |
| `ui.detailed-bsod` | **Detailed BSOD (show stop code parameters, no sad face)**<br><sub>Old-style crash screen with driver names and bugcheck parameters.</sub> | safe |  | 2× registry |
| `ui.drag-tray-off` | **Disable the drag-to-share tray (25H2)**<br><sub>Removes the app-share bar that appears at the top of the screen when dragging a file.</sub> | safe | build 26200+ | 1× registry |

## 📁 explorer (12)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `explorer.show-extensions` | **Show file extensions & hidden files**<br><sub>Security basic: never be fooled by 'invoice.pdf.exe' again.</sub> | safe | ★ | 2× registry |
| `explorer.open-this-pc` | **Open File Explorer to 'This PC'**<br><sub>Skips Home/Quick access on launch.</sub> | safe |  | 1× registry |
| `explorer.no-recent-frequent` | **Disable recent files & frequent folders in Home**<br><sub>Privacy: nothing you opened shows up in Explorer Home or Start.</sub> | safe |  | 4× registry |
| `explorer.hide-home-gallery` | **Hide Home & Gallery from the navigation pane**<br><sub>Removes the two 23H2+ entries from Explorer's left sidebar.</sub> | safe | build 22621+ | 2× registry |
| `explorer.hide-onedrive` | **Hide OneDrive from the navigation pane**<br><sub>Keeps OneDrive installed but removes its sidebar entry.</sub> | safe |  | 1× registry |
| `explorer.hide-duplicate-drives` | **Hide duplicate removable drives in the sidebar**<br><sub>USB drives appear once (under This PC) instead of twice.</sub> | safe |  | 1× registryDeleteKey |
| `explorer.compact-mode` | **Compact view (denser rows)**<br><sub>Windows 10-style spacing in file lists.</sub> | safe |  | 1× registry |
| `explorer.no-shortcut-suffix` | **No '- Shortcut' suffix on new shortcuts**<br><sub>New shortcuts are named exactly like their target.</sub> | safe |  | 1× registry |
| `explorer.no-lowdisk-nag` | **Disable low disk space warnings**<br><sub>For small SSDs where the warning is a permanent annoyance.</sub> | safe |  | 1× registry |
| `explorer.copy-move-to` | **Add 'Copy to' / 'Move to' to the context menu**<br><sub>Classic folder-picker actions on right-click (visible in the full context menu).</sub> | safe |  | 2× registry |
| `explorer.search-no-bing` | **Start/Explorer search: local only (no Bing, no web)**<br><sub>Search box no longer sends keystrokes to Bing; removes web results and Cortana consent.</sub> | safe | ★ | 8× registry |
| `explorer.store-search-suggestions-off` | **Disable Microsoft Store suggestions in search**<br><sub>Search stops suggesting 'Install X from the Store' for apps you don't have (deny-ACL on store.db, Win11Debloat technique).</sub> | moderate | build 22621+ | 1× powershell |

## 🌐 edge (3)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `edge.no-ads` | **Edge: remove ads, shopping, sidebar nags & first-run promos**<br><sub>New tab page content off, shopping assistant off, no default-browser campaigns, no wallet/donation, no Acrobat upsell, no recommendations.</sub> | safe | ★ | 13× registry |
| `edge.no-telemetry` | **Edge: disable telemetry, startup boost & background mode**<br><sub>No metrics/personalization reporting; Edge no longer preloads at logon or stays running after you close it.</sub> | safe | ★ | 6× registry |
| `edge.uninstall` | **Force-uninstall Microsoft Edge (keeps WebView2)**<br><sub>Uses the EEA AllowUninstall unlock + stub MicrosoftEdge.exe trick and runs setup.exe --uninstall --system-level --force-uninstall. Widgets, Copilot and some Store links depend on Edge; WebView2 runtime is kept for apps.</sub> | advanced | ✖ | 1× powershell, 1× registry |

## 🔄 updates (8)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `updates.no-auto-reboot` | **Never auto-restart while someone is logged in**<br><sub>Updates install but wait for you to reboot.</sub> | safe | ★ | 2× registry |
| `updates.no-feature-asap` | **Don't get feature updates 'as soon as available'**<br><sub>Opts out of continuous innovation early rollouts; you get new features on the stable cadence.</sub> | safe | ★ | 2× registry |
| `updates.defer-feature` | **Defer feature updates by 365 days**<br><sub>Stay on the current release for a year; security updates keep flowing.</sub> | moderate |  | 3× registry |
| `updates.no-drivers` | **Exclude drivers from Windows Update**<br><sub>Prevents WU from replacing your GPU/audio/chipset drivers with older generic ones.</sub> | moderate |  | 5× registry |
| `updates.delivery-optimization-off` | **Disable Delivery Optimization P2P upload**<br><sub>Your PC stops seeding updates to other PCs on the internet (DownloadMode 0 = HTTP only).</sub> | safe | ★ | 2× registry |
| `updates.store-auto-off` | **Disable automatic Store app updates**<br><sub>Store apps update only when you open the Store and ask.</sub> | moderate |  | 2× registry |
| `updates.no-mrt` | **Don't push Malicious Software Removal Tool monthly**<br><sub>Skips the ~100 MB monthly MRT download (Defender still protects you).</sub> | safe |  | 1× registry |
| `updates.pause-forever` | **Pause all Windows Updates (until 2099)**<br><sub>Sets the pause window far into the future. Security-risky: revert to receive patches again.</sub> | advanced |  | 6× registry |

## 📡 network (8)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `net.tcp-tuning` | **TCP tuning: CTCP, RSS, ECN, no heuristics/timestamps**<br><sub>netsh int tcp: congestion provider CTCP, receive-side scaling on, ECN on, timestamps off, heuristics off, initial congestion window 10. Modest throughput/latency gain on fast links.</sub> | safe |  | 4× command |
| `net.nagle-off` | **Disable Nagle's algorithm (TcpAckFrequency/TcpNoDelay)**<br><sub>Lower latency for small packets (online games, RDP) on every active adapter. Can slightly increase packet count.</sub> | moderate | ⟳ | 1× powershell |
| `net.llmnr-netbios-off` | **Disable LLMNR & NetBIOS name resolution**<br><sub>Closes classic LAN spoofing vectors (Responder attacks). Only DNS/mDNS is used for name resolution.</sub> | moderate |  | 1× powershell, 1× registry |
| `net.teredo-off` | **Disable Teredo / ISATAP / 6to4 tunnels**<br><sub>Legacy IPv6 transition tunnels. Note: Xbox app party chat may need Teredo.</sub> | moderate |  | 3× command |
| `net.dns-cloudflare` | **Set DNS to Cloudflare (1.1.1.1) with DoH**<br><sub>Applies 1.1.1.1 / 1.0.0.1 (+IPv6) on every connected adapter and registers DNS-over-HTTPS templates.</sub> | moderate |  | 1× powershell |
| `net.dns-quad9` | **Set DNS to Quad9 (9.9.9.9, malware-blocking) with DoH**<br><sub>Privacy-focused resolver that blocks known malicious domains.</sub> | moderate |  | 1× powershell |
| `net.smb1-off` | **Remove SMBv1 protocol**<br><sub>The WannaCry vector. Only very old NAS boxes/printers still need it.</sub> | safe | ⟳ ★ | 1× feature, 1× registry |
| `net.qos-reserve-zero` | **QoS: reserve 0 % bandwidth for the system**<br><sub>NonBestEffortLimit 0 — the packet scheduler can't hold back 20 % of your link for QoS-tagged system traffic. Harmless; helps only if something on the PC actually uses QoS.</sub> | safe |  | 1× registry |

## 🛡 security (7)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `sec.wpbt-off` | **Block OEM firmware app injection (WPBT)**<br><sub>Windows Platform Binary Table lets the BIOS silently install vendor software on every boot (Lenovo/ASUS/… bloat). This disables it.</sub> | safe | ⟳ ★ | 1× registry |
| `sec.defender-cloud-samples` | **Defender: never send file samples to Microsoft**<br><sub>Keeps real-time protection but sets SubmitSamplesConsent to 'Never send' and MAPS reporting to basic.</sub> | safe |  | 1× powershell, 1× registry |
| `sec.bitlocker-auto-off` | **Prevent automatic BitLocker device encryption**<br><sub>24H2 silently encrypts new installs and ties the key to your Microsoft account. This blocks auto-encryption (you can still enable BitLocker manually).</sub> | safe | build 26100+ | 1× registry |
| `sec.no-auto-signon` | **Disable automatic sign-in after update restarts**<br><sub>Windows won't cache your credentials to auto-logon after an update reboot.</sub> | safe |  | 1× registry |
| `sec.uac-max` | **UAC: always notify (secure desktop)**<br><sub>Highest UAC level; also prompts when Windows settings change.</sub> | safe |  | 2× registry |
| `sec.rdp-file-warning-off` | **Suppress the .rdp file security warning dialog**<br><sub>For people who open saved RDP connections many times a day.</sub> | moderate |  | 2× registry |
| `sec.exe-launch-warning-off` | **Disable 'Open File - Security Warning' for downloads**<br><sub>Stops zone-identifier (Mark of the Web) prompts. SmartScreen still checks executables.</sub> | advanced |  | 2× registry |

## 🔋 power (8)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `power.ultimate-plan` | **Enable & activate Ultimate Performance power plan**<br><sub>Unhides the hidden Ultimate Performance scheme and makes it active. Desktops only; laptops should keep Balanced.</sub> | moderate |  | 1× powershell |
| `power.high-performance-plan` | **Activate High Performance power plan**<br><sub>The standard high-performance scheme; safer than Ultimate on laptops plugged in.</sub> | safe |  | 1× command |
| `power.fast-startup-off` | **Disable Fast Startup (hybrid shutdown)**<br><sub>Shutdown becomes a real shutdown: fixes dual-boot disk locks, Wake-on-LAN and 'reboot fixes it' bugs.</sub> | safe | ★ | 1× registry |
| `power.hibernate-off` | **Disable hibernation & delete hiberfil.sys**<br><sub>Frees RAM-sized space on the system drive. Also disables Fast Startup.</sub> | moderate |  | 1× command |
| `power.usb-selective-suspend-off` | **Disable USB selective suspend**<br><sub>Stops mice/keyboards/DACs from being put to sleep and lagging on wake. Desktop recommended.</sub> | safe |  | 1× command |
| `power.modern-standby-network-off` | **Disconnect network during Modern Standby (laptops)**<br><sub>Stops the laptop from waking, downloading and draining the battery in your bag.</sub> | safe |  | 2× registry |
| `power.cpu-unpark` | **Unlock & disable CPU core parking (current plan)**<br><sub>Sets minimum unparked cores to 100 % so all cores stay ready. Higher idle power on laptops.</sub> | moderate |  | 1× command |
| `power.desktop-max` | **Desktop power: PCIe ASPM off, USB3 LPM off, disks never sleep, CPU min 100 %, boost Aggressive**<br><sub>Five hidden power-plan settings that cause hitching on desktops: PCI Express link power management, USB 3 link power management, hard-disk sleep, minimum processor state and the turbo-boost policy. Applied to the active plan. Do not use on laptops.</sub> | moderate |  | 5× command |

## 🧪 advanced (10)

| id | tweak | risk | notes | what it touches |
|---|---|---|---|---|
| `adv.vbs-off` | **Disable VBS / Memory Integrity (HVCI)**<br><sub>Up to 5-15 % more FPS on some CPUs at the cost of kernel exploit protection. Breaks nothing else; WSL2/Hyper-V keep working. Not possible if UEFI locks VBS.</sub> | advanced | ⟳ | 3× registry |
| `adv.spectre-meltdown-off` | **Disable Spectre/Meltdown CPU mitigations**<br><sub>FeatureSettingsOverride = 3. Noticeable I/O and syscall speedup on older Intel CPUs. Reduces security against side-channel attacks.</sub> | advanced | ⟳ | 2× registry |
| `adv.legacy-boot-menu` | **Legacy F8 boot menu**<br><sub>Text-mode boot menu with Safe Mode via F8 (slower boot by ~1 s).</sub> | moderate |  | 1× command |
| `adv.compact-os` | **CompactOS: compress system files (saves 2-3 GB)**<br><sub>Transparent XPRESS compression of the Windows folder. Negligible CPU cost on modern hardware, great on small SSDs.</sub> | moderate |  | 1× command |
| `adv.crash-dump-small` | **Small memory dumps instead of full kernel dumps**<br><sub>256 KB minidumps on BSOD. Saves gigabytes of disk and shortens crash-reboot time.</sub> | safe |  | 1× registry |
| `adv.utc-clock` | **Hardware clock in UTC (dual-boot with Linux/macOS)**<br><sub>Stops the time jumping by your timezone offset when switching OS.</sub> | safe | ⟳ | 1× registry |
| `adv.windows-sandbox` | **Enable Windows Sandbox**<br><sub>Disposable VM for testing sketchy installers. Requires Pro/Enterprise and virtualization.</sub> | safe | ⟳ Pro/Enterprise/Education | 1× feature |
| `adv.wsl` | **Enable WSL2 prerequisites**<br><sub>Virtual Machine Platform + Windows Subsystem for Linux features.</sub> | safe | ⟳ | 2× feature |
| `adv.dev-mode` | **Developer mode, long paths & PowerShell 7 friendly**<br><sub>Enables Developer Mode (sideload, symlinks without admin), Win32 long paths, and sets execution policy RemoteSigned.</sub> | safe |  | 1× powershell, 2× registry |
| `adv.legacy-photo-viewer` | **Restore Windows Photo Viewer**<br><sub>Registers the classic viewer for jpg/png/gif/bmp/tiff so it appears in 'Open with'.</sub> | safe |  | 1× powershell |

## Profiles

### ⚖️ Balanced (recommended) (`balanced`, 28 tweaks)

Everything tagged 'recommended': telemetry off, ads gone, junk apps removed, Copilot/Recall off, sane defaults. Zero functionality loss.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.widgets` · `bloat.consumer-features` · `perf.multimedia-profile` · `gaming.game-dvr-off` · `gaming.nic-power-off` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `ui.classic-context-menu` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `explorer.show-extensions` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.delivery-optimization-off` · `net.smb1-off` · `sec.wpbt-off` · `power.fast-startup-off`

### 🔒 Privacy Max (`privacy`, 38 tweaks)

Every safe and moderate privacy/AI/Edge tweak, hosts-file telemetry block, local-only search, Quad9 DNS, no cloud sync.

`privacy.telemetry` · `privacy.advertising-id` · `privacy.activity-history` · `privacy.input-personalization` · `privacy.feedback` · `privacy.error-reporting` · `privacy.location` · `privacy.app-permissions` · `privacy.wifi-sense` · `privacy.cloud-clipboard-sync` · `privacy.app-launch-tracking` · `privacy.experiments` · `privacy.speech-model-updates` · `privacy.cdp-user-service` · `privacy.nvidia-telemetry` · `privacy.telemetry-hosts` · `ai.copilot` · `ai.recall` · `ai.click-to-do` · `ai.agents-connectors` · `ai.fabric-service` · `ai.paint` · `ai.notepad` · `ai.edge-copilot` · `ai.gaming-copilot` · `ai.input-insights` · `ai.settings-pages` · `bloat.widgets` · `bloat.consumer-features` · `svc.diagnostics` · `explorer.no-recent-frequent` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.delivery-optimization-off` · `net.llmnr-netbios-off` · `net.dns-quad9` · `sec.defender-cloud-samples`

### 🎮 Gaming (`gaming`, 46 tweaks)

Balanced + Game DVR off, HAGS, windowed optimisations, no mouse accel, multimedia scheduler, Ultimate power plan, no driver updates from WU, USB suspend off, TCP tuning. Keeps Xbox services for Game Pass.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.widgets` · `bloat.consumer-features` · `perf.visual-effects` · `perf.foreground-priority` · `perf.multimedia-profile` · `perf.power-throttling-off` · `gaming.game-mode` · `gaming.hags` · `gaming.windowed-optimizations` · `gaming.game-dvr-off` · `gaming.gamebar-popups` · `gaming.mouse-acceleration-off` · `gaming.keyboard-repeat` · `gaming.sticky-keys-off` · `gaming.timer-resolution` · `gaming.memory-tuning` · `gaming.nic-power-off` · `gaming.mouse-keyboard-queue` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `ui.classic-context-menu` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `explorer.show-extensions` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.no-drivers` · `updates.delivery-optimization-off` · `net.tcp-tuning` · `net.nagle-off` · `net.smb1-off` · `sec.wpbt-off` · `power.ultimate-plan` · `power.fast-startup-off` · `power.usb-selective-suspend-off`

### 🧹 Minimal / Debloat (`minimal`, 42 tweaks)

Strip Windows down: all bloatware sets incl. Xbox, Teams, OneDrive, optional inbox apps; services to manual; search indexer off; Edge ads/telemetry off.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.oem` · `bloat.xbox` · `bloat.teams-outlook` · `bloat.widgets` · `bloat.cross-device` · `bloat.onedrive` · `bloat.optional-apps` · `bloat.consumer-features` · `perf.multimedia-profile` · `perf.sysmain` · `perf.search-indexer` · `gaming.game-dvr-off` · `gaming.nic-power-off` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `svc.diagnostics` · `svc.hyperv` · `svc.edge-update` · `svc.maintenance-tasks` · `ui.classic-context-menu` · `ui.hide-taskview-chat` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `explorer.show-extensions` · `explorer.hide-home-gallery` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.delivery-optimization-off` · `net.smb1-off` · `sec.wpbt-off` · `power.fast-startup-off`

### 💻 Developer (`developer`, 38 tweaks)

Balanced + dev mode, long paths, WSL2, Sandbox, verbose boot, detailed BSOD, extensions shown, classic context menu, no auto-reboot, fast timeouts.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.widgets` · `bloat.consumer-features` · `perf.menu-delay` · `perf.multimedia-profile` · `perf.app-timeouts` · `gaming.game-dvr-off` · `gaming.nic-power-off` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `ui.classic-context-menu` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `ui.verbose-logon` · `ui.detailed-bsod` · `explorer.show-extensions` · `explorer.open-this-pc` · `explorer.copy-move-to` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.delivery-optimization-off` · `net.smb1-off` · `sec.wpbt-off` · `power.fast-startup-off` · `adv.crash-dump-small` · `adv.windows-sandbox` · `adv.wsl` · `adv.dev-mode`

### 🔋 Laptop / Battery (`laptop`, 33 tweaks)

Balanced + background apps off, Modern Standby network off, reduced effects, safe services to manual. Never touches power throttling or the Ultimate plan.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.widgets` · `bloat.consumer-features` · `perf.visual-effects` · `perf.multimedia-profile` · `perf.background-apps` · `gaming.game-dvr-off` · `gaming.nic-power-off` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `svc.hyperv` · `ui.classic-context-menu` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `explorer.show-extensions` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.delivery-optimization-off` · `net.smb1-off` · `sec.wpbt-off` · `sec.bitlocker-auto-off` · `power.fast-startup-off` · `power.modern-standby-network-off`

### 🖥️ Gaming Desktop Max (`gaming-desktop`, 52 tweaks)

Everything in Gaming plus desktop-only power and latency work: PCIe/USB3/disk power saving off, CPU min 100 % + aggressive boost, no NIC power saving, global 0.5 ms timer, memory compression off, MPO off, no audio ducking, low-impact Defender, QoS reserve 0, Hyper-V guest services off. Advanced tweaks (MSI mode, NIC low-latency, hypervisor off) stay opt-in.

`privacy.telemetry` · `privacy.advertising-id` · `ai.copilot` · `ai.recall` · `bloat.ms-junk` · `bloat.third-party` · `bloat.widgets` · `bloat.consumer-features` · `perf.visual-effects` · `perf.foreground-priority` · `perf.multimedia-profile` · `perf.power-throttling-off` · `gaming.game-mode` · `gaming.hags` · `gaming.windowed-optimizations` · `gaming.game-dvr-off` · `gaming.gamebar-popups` · `gaming.mouse-acceleration-off` · `gaming.keyboard-repeat` · `gaming.sticky-keys-off` · `gaming.mpo-off` · `gaming.timer-resolution` · `gaming.memory-tuning` · `gaming.nic-power-off` · `gaming.mouse-keyboard-queue` · `gaming.audio-ducking-off` · `gaming.defender-low-impact` · `svc.safe-manual` · `svc.diagnostics` · `svc.hyperv` · `ui.classic-context-menu` · `ui.end-task` · `ui.start-no-recommended` · `ui.notifications-quiet` · `explorer.show-extensions` · `explorer.search-no-bing` · `edge.no-ads` · `edge.no-telemetry` · `updates.no-auto-reboot` · `updates.no-feature-asap` · `updates.no-drivers` · `updates.delivery-optimization-off` · `net.tcp-tuning` · `net.nagle-off` · `net.smb1-off` · `net.qos-reserve-zero` · `sec.wpbt-off` · `power.ultimate-plan` · `power.fast-startup-off` · `power.usb-selective-suspend-off` · `power.cpu-unpark` · `power.desktop-max`

