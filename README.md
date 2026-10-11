# mango-minimal — lightweight Wayland setup

My daily-driver config, trimmed down for my friend **ahmoodio** (and anyone
whose "minimal" setup still idles at 1.6 GB RAM).

Stack: **mango** (tiling Wayland compositor, ~90 MB) + **waybar** + **swaync**
+ **rofi** + **foot / alacritty / kitty** + **btop**. No GNOME/KDE, no Electron
services at login.

## Quick start (for ahmoodio)

```bash
git clone <this-repo-url> mango-minimal
cd mango-minimal
chmod +x install.sh
./install.sh
```

Then log out → at the login screen pick **mango** as the session.
Inside: `Alt+Enter` terminal, `Alt+Space` launcher, `Super+R` reload config.

Flags:

| flag | effect |
|---|---|
| `--yes` | skip confirmation prompts |
| `--link` | symlink dotfiles instead of copying (edits sync back to the repo) |
| `--no-packages` | dotfiles only, don't touch the package manager |
| `--help` | help text |

Supports **Arch / CachyOS** (`pacman`, `mangowm` from repos or AUR),
**Debian / Ubuntu / Mint / Pop!** (`apt`, mango built from source),
**Fedora / Nobara** (`dnf`, mango built from source).
Unknown distro → dotfiles still install, packages are skipped with a warning.

Re-running is safe: existing configs are backed up to
`~/.config-backup-<timestamp>/`, never deleted.

## What's inside

```
install.sh                  # distro-aware installer (packages + dotfiles)
dotfiles/
  .config/mango/config.conf # compositor: blur/shadows OFF, tuned for Intel iGPU,
                            #   tiling defaults, keybinds (see below)
  .config/waybar/           # minimal floating bar: workspaces | net cpu mem vol tray clock
  .config/rofi/config.rasi  # minimal dark launcher theme
  .config/alacritty/        # nord-ish, opacity 0.8
  .config/kitty/            # gray-black minimal theme
  .config/foot/             # minimal foot.ini (lightest terminal, ~15 MB)
  .config/btop/             # btop.conf + noctalia theme (falls back to Default if missing)
  .local/bin/               # wallpaper-switcher.sh (rofi + awww/mpvpaper, optional)
```

Only the lightweight bits are shipped — no browser profiles, no Discord /
VESKTOP data, no caches, no machine-specific overclock scripts.

## Keybinds (mango)

| keys | action |
|---|---|
| `Alt+Enter` | alacritty |
| `Alt+Space` | rofi app launcher |
| `Super+R` | reload mango config |
| `Super+1..9` | go to workspace |
| `Alt+1..9` | move window to workspace |
| `Alt+Tab` | overview |
| `Alt+W` | close window |
| `Super+M` | quit mango |
| `Super+Q` / `Super+Shift+Q` | screen-record toggle/stop (needs `record-toggle` script, optional) |
| `Super+S` | screenshot to `~/Pictures/Screenshots/` (grim) |

Full list: [`dotfiles/.config/mango/config.conf`](dotfiles/.config/mango/config.conf).

## Why 1.6 GB idle? (the RAM guide)

The compositor is almost never the problem. Real numbers from this machine:

- mango: **~90 MB**. GNOME Shell / KDE Plasma: **600–900 MB** before apps.
- foot: **~15 MB**. GNOME Terminal / Konsole: more, plus their services.
- waybar + swaync + rofi: **tens of MB combined**.

So switching DE → mango saves ~0.5 GB. The rest is usually:

1. **Electron apps at login** — Discord / Slack / Spotify / VSCodium are each
   300–700 MB. Don't autostart them. Prefer 1 browser tab over the app.
2. **Browser tabs** — ~150–250 MB each. Idle with 8 tabs = 1.6 GB by itself.
3. **Indexers & services** — baloo (KDE), tracker (GNOME), snapd, docker,
   libvirt, packagekit. Disable what you don't use:
   `systemctl --user disable ...` / `sudo systemctl disable ...`
4. **Tray / background apps** — Steam, Nextcloud, Dropbox, screenshot tools,
   RGB daemons. Kill and measure.

Measure, don't guess:

```bash
free -h
ps aux --sort=-%mem | head -15
btop   # shipped config, press q to quit
```

Target: fresh mango login should idle at **~500–800 MB** (`free -h`).
If you're still at 1.6 GB, the top 5 lines of `ps aux` will name the culprit —
it's never the bar or the launcher.

More trims if you want them:

- Use `foot` over `kitty` over Electron terminals.
- `swaync` stays; GNOME notifications pull half of GNOME with them.
- Keep `~/.config/autostart/` empty.
- Firefox: `about:processes` shows per-tab RAM; enable `about:memory` GC on idle.
- Swap `easyeffects` / noise-suppression chains off when not in calls.

## Notes / caveats

- `mango/config.conf` runs `awww-daemon`, `waybar`, `swaync`, portals at
  startup and binds `Super+A` to `wallpaper-switcher.sh`. If you don't use
  `awww`/`mpvpaper`, comment those `exec-once` lines out — everything else
  works without them.
- Waybar uses the `ext/workspaces` module (dwl/mango protocol). Stock distro
  waybar builds include it; if your build lacks it, swap to your compositor's
  module or delete that block.
- Screenshots need `grim` (+ `slurp`/`wl-clipboard` for regions). Installed
  by default via `install.sh`.
- Nerd Font: waybar/rofi/terminals assume JetBrainsMono Nerd Font.
  Install it or expect box glyphs (installer handles this per distro).

## Send / push this repo

```bash
cd mango-minimal
git init -b main
git add .
git commit -m "lightweight mango setup"
gh repo create mango-minimal --public --source=. --push   # needs gh + login
# ...or push to any remote manually, then send ahmoodio the link.
```
