<div align="center">

<img src="ryoku/assets/brand/logo-mark-v2.png" alt="Ryoku Logo" width="140" />

# scushi-ryoku

**Scushi's Personal Arch Linux + Hyprland Daily Driver OS & Dotfiles**  
*Built on [Ryoku](https://github.com/Ryoku-dev/ryoku) with bespoke Wayland patches, custom QML modules, and tailored workflow ergonomics.*

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-E2342A?style=for-the-badge)](LICENSE)
[![Built on Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1C2?style=for-the-badge&logoColor=white)](https://hypr.land)
[![Quickshell](https://img.shields.io/badge/Quickshell-FFADE4?style=for-the-badge&logoColor=black)](https://github.com/outfoxxed/quickshell)
[![Fish Shell](https://img.shields.io/badge/Fish-43C0C0?style=for-the-badge&logo=fish&logoColor=white)](https://fishshell.com)
[![Neovim](https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io)
[![Kitty](https://img.shields.io/badge/Kitty-202020?style=for-the-badge&logoColor=white)](https://sw.kovidgoyal.net/kitty/)

<kbd>[Live Site](https://scushi.dev)</kbd> &middot; <kbd>[Dotfiles Tour](#dotfiles-directory-tour)</kbd> &middot; <kbd>[Custom Features](#key-customizations--features)</kbd> &middot; <kbd>[Hyprland Rules](#hyprland-configuration--workspace-layout)</kbd> &middot; <kbd>[Installation](#installation--deployment)</kbd> &middot; <kbd>[Upstream Ryoku](https://github.com/Ryoku-dev/ryoku)</kbd>

</div>

---

## Overview

This repository represents the exact, battle-tested system configuration and dotfiles that I use every single day for software development, reverse engineering, academic coursework, and gaming.

It is built as a personalized fork and extension of **[Ryoku](https://github.com/Ryoku-dev/ryoku)**, an opinionated Arch Linux desktop environment powered by Hyprland and Quickshell. On top of the upstream base, I have developed bespoke patches for interactive wallpaper engine compatibility, dynamic MPRIS-gated audio visualization, automated solar color temperature scheduling, custom Neovim development runners, and a distinctive sharp-geometry aesthetic.

Whether you came here from the **dotfiles** link on **[scushi.dev](https://scushi.dev)** or stumbled upon this on GitHub, this repo provides full transparency into my entire desktop environment.

---

## Daily Driver Vitals & Hardware

| Component | Specification | Notes |
| :--- | :--- | :--- |
| **OS** | Arch Linux (x86_64 rolling) | Standard Arch kernel + CachyOS optimizations |
| **Compositor** | Hyprland 0.54+ | Configured via Ryoku's Lua `hl` API |
| **Desktop Shell** | Quickshell (Qt6 / QML) | Custom `Desktop.qml` & `Visualizer.qml` patches |
| **Primary Display** | `DP-2`: 2560x1440 @ 144Hz | Main workspace for code, terminal, and games |
| **Secondary Display**| `HDMI-A-1`: 1920x1080 @ 72Hz | Positioned at `2560x324` for Discord & music |
| **Theme & Palette** | Signature Scushi Dark / Magenta | Accent `#ffade4` (`rgb(255, 173, 229)`), Dark `#131313` |
| **Window Geometry** | Sharp / Rectangular | `rounding = 0`, `gaps_in = 9`, `gaps_out = 9`, `border_size = 1` |
| **Shell & Terminal**| Fish Shell + Kitty / Ghostty | Atuin history, `background_opacity 0.7`, `cursor_trail 0` |
| **Editor** | Neovim (LazyVim base) | Multi-language floating terminal runner (`<F5>` / `<leader>r`) |
| **Bar Layout** | QS Bar (`islands` mode) | Centered 10-workspace magic island, corner radius 8 |

---

## Key Customizations & Features

### 1. HyprWpE Dynamic Wallpaper Engine Integration (`quickshell/Desktop.qml`)
Ryoku's standard desktop background layer actively renders static wallpapers or its own video engine. To seamlessly run interactive and animated live wallpapers from **[HyprWpE](https://github.com/SushiBirb/HyprWpE)** (such as `mpvpaper`, `web_viewer.py`, or `linux-wallpaperengine`), I implemented a background process probe in Quickshell:

```qml
// Detect external wallpaper engines (HyprWpE: mpvpaper, web_viewer.py, linux-wallpaperengine)
// When an external wallpaper is running on the background layer, yield the backdrop so it shows through.
property bool hyprwpeActive: false

Process {
    id: hyprwpeProbe
    command: ["pgrep", "-f", "mpvpaper|web_viewer.py|linux-wallpaperengine"]
    onExited: (code) => {
        root.hyprwpeActive = (code === 0);
    }
}
```
When an external engine runs, Quickshell immediately yields its solid wallpaper backdrop and frosted glass effects, preventing visual tearing and letting full 144Hz live wallpapers show through.

### 2. MPRIS Audio-Gated Reactive Visualizer (`quickshell/Visualizer.qml`)
Instead of a desktop audio visualizer constantly consuming GPU/CPU cycles or cluttering the screen when nothing is playing, `Visualizer.qml` connects directly to DBus MPRIS services:

- Dynamically queries all active MPRIS media players (with dedicated matching for **Sone** and browser playback).
- Automatically lifts and renders the visualizer onto the desktop when music is actively playing.
- Seamlessly hides and pauses the visualizer when music is stopped or paused.

### 3. Solar Night Light Scheduler (`hyprsunset-scheduler.py`)
An offline, mathematical night light scheduler written in Python:
- Caches local latitude and longitude coordinates.
- Computes exact daily sunrise and sunset times using offline **NOAA solar calculation algorithms**.
- Generates a buttery-smooth **1-hour color temperature ramp** starting at sunset (transitioning from 6500K daylight down to 4000K night temperature).
- Smoothly transitions back to daylight at sunrise.
- Updates color temperature dynamically via `hyprctl` IPC without flickering or frame drops.

### 4. Universal Neovim Quick-Runner (`nvim/lua/config/keymaps.lua`)
A single keypress (`<F5>` or `<leader>r`) in Neovim:
1. Automatically formats the buffer with `conform.nvim` (Prettier, Clang-Format, CSharpier, etc.).
2. Auto-saves modified buffers.
3. Detects the filetype and executes the appropriate compiler/interpreter in an ergonomic floating terminal window (via Snacks.terminal):
   - **C++ / C:** `g++ -std=c++20 -Wall -Wextra -O2` / `gcc`
   - **C#:** `dotnet run` (auto-detects `.csproj` / `.sln` project roots)
   - **Rust:** `cargo run` (auto-detects `Cargo.toml`)
   - **Python:** `python3`
   - **Java:** `javac` + `java`
   - **TypeScript / JavaScript:** `npx tsx` / `node`
   - **Bash / Shell:** `bash`
   - **HTML:** Launches directly in `zen-browser` via `xdg-open`

### 5. Fastfetch with Cbonsai & Custom Vitals (`fastfetch/config.jsonc`)
A customized terminal greeting featuring dynamic `cbonsai` procedural ASCII bonsai trees, signature magenta headers, and structured telemetry cards:
- **VITALS:** CPU load, GPU detection, RAM usage, and NVMe disk capacity.
- **SYSTEM:** Kernel, Hyprland WM identifier, Fish shell, installed pacman/yay package count.
- **SESSION:** System uptime, OS install age calculation in days, and terminal host.

---

## Hyprland Configuration & Workspace Layout

My Hyprland overrides in `dotfiles/hypr/user.lua` enforce strict window assignments, display pinning, and input handling:

```
[ DP-2: 2560x1440 @ 144Hz ]                [ HDMI-A-1: 1920x1080 @ 72Hz ]
┌─────────────────────────────┐            ┌─────────────────────────────┐
│ Workspace 1: Zen Browser    │            │ Workspace 2: Discord        │
│ Workspace 3: Steam Client   │            │ Workspace 10: Sone (Music)  │
│ Workspace 5: Gaming Arena   │            └─────────────────────────────┘
└─────────────────────────────┘
```

### Window Rules & Ergonomics
- **Dedicated Gaming Workspace (WS 5):** Automatic detection for Steam games (`^steam_app_.*$`), *Marvel's Spider-Man*, and Roblox/Sober (`^sober$`, `^org\.vinegarhq\.Sober$`) routed directly to Workspace 5 with auto-focus.
- **Strict Opacity Enforcement:** Window classes for `Zen`, `Discord`, and `Sone` are permanently locked to 100% opacity (`opaque = true`) to prevent readability fatigue from inactive window dimming.
- **Continuous Follow-Mouse Hover Enforcement:** A persistent background event listener synchronizes with `desktop.json` to ensure window focus tracks cursor hover without getting stuck when returning from Proton/Wine full-screen games.
- **Single Super Tap Launcher:** Releasing the `Super` (Windows) key without chords opens the Ryoku app launcher instantly.
- **Scratchpad Workspace:** `SUPER + S` toggles a floating scratchpad; `SUPER + ALT + S` stashes or un-stashes the focused window.
- **Night Light Manual Override:** `SUPER + U` toggles hyprsunset immediately.
- **Controller Ergonomics:** Disables the PlayStation / DualShock / DualSense touchpad mouse emulation to prevent unintentional cursor movement while gaming with a connected gamepad.

---

## Dotfiles Directory Tour

The `dotfiles/` directory is organized modularly and mirrors `~/.config`:

```
dotfiles/
├── hypr/
│   ├── user.lua                     # Core user overrides (window rules, inputs, keybinds)
│   ├── settings.lua                 # Hyprland appearance, gaps (9px), borders (1px, 0 radius)
│   ├── rebinds.lua                  # Keybind overrides
│   ├── monitors.lua                 # Output resolutions, refresh rates, and relative offsets
│   ├── monitors_user.lua            # Manual pin overrides
│   └── scripts/
│       ├── hyprsunset-scheduler.py  # Automated NOAA solar sunrise/sunset night light daemon
│       └── user-autostart.sh        # Boot orchestration (network check, wallpaper, core apps)
├── quickshell/
│   ├── shell/modules/desktop/
│   │   └── Desktop.qml              # HyprWpE external live wallpaper passthrough patch
│   ├── shell/modules/visualizer/
│   │   └── Visualizer.qml           # Sone MPRIS-gated audio visualizer patch
│   └── reload-cover/assets/
│       └── logo.png                 # Custom reload cover logo
├── fish/
│   ├── config.fish                  # Main fish initialization and path declarations
│   └── user.fish                    # Atuin history integration, typo helpers (pamcan, celar)
├── kitty/
│   ├── user.conf                    # background_opacity 0.7, cursor_trail 0
│   ├── kitty.conf                   # Font stack (Space Grotesk, JetBrains Mono)
│   └── current-theme.conf           # Signature Scushi dark/magenta color palette
├── ghostty/
│   ├── config                       # Ghostty terminal config
│   └── ryoku-colors                 # Ghostty palette definition
├── fastfetch/
│   └── config.jsonc                 # cbonsai ASCII art, magenta accents, system vitals
├── btop/
│   └── btop.conf                    # System monitor layout, vim keys, braille graphs
├── nvim/
│   └── lua/config/
│       └── keymaps.lua              # F5 universal compile-and-run floating terminal
├── qt6ct/
│   └── qt6ct.conf                   # Qt application font and color synchronization
└── ryoku/
    ├── desktop.json                 # Ryoku desktop settings (rounding 0, gaps 9, pop style)
    ├── theme.json                   # Wallpaper color-following mode
    ├── shell.json                   # QS Bar top island layout, widget assignments
    └── matugen.json                 # TonalSpot material color scheme preferences
```

---

## Installation & Deployment

### 1. Clone the Repository
```bash
git clone https://github.com/SushiBirb/scushi-ryoku.git
cd scushi-ryoku
```

### 2. Preview Deployment (Dry-Run)
To see exactly what files will be linked without touching your existing configuration:
```bash
./install.sh --dry-run
```

### 3. Deploy Dotfiles
To deploy with automatic backups of any existing configurations in `~/.config`:
```bash
# Symlink mode (recommended for continuous development)
./install.sh

# Or copy mode (standalone copy without symlinks)
./install.sh --copy
```

### 4. Reload Desktop Surfaces
```bash
# Reload Hyprland window rules and keybinds
hyprctl reload

# Reload Quickshell desktop, bar, and modules
ryoku reload
```

---

## Credits & Upstream Attribution

`scushi-ryoku` is built upon the incredible work of the **[Ryoku](https://github.com/Ryoku-dev/ryoku)** distribution:
- **Upstream Project:** [Ryoku-dev/ryoku](https://github.com/Ryoku-dev/ryoku)
- **License:** GNU General Public License v3.0 ([LICENSE](LICENSE))
- **Shell Architecture:** [Quickshell](https://github.com/outfoxxed/quickshell)
- **Compositor:** [Hyprland](https://hypr.land)
- **Live Wallpaper Engine:** [HyprWpE](https://github.com/SushiBirb/HyprWpE)
- **Author & Customizations:** [SushiBirb / Scushi](https://scushi.dev)
