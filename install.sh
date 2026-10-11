#!/usr/bin/env bash
#
# install.sh -- lightweight mango + waybar setup
#
# Usage:
#   ./install.sh              # install packages + dotfiles (copy mode, prompts first)
#   ./install.sh --yes        # no prompts (for scripts)
#   ./install.sh --link       # symlink dotfiles instead of copying (for hacking on them)
#   ./install.sh --no-packages# only install dotfiles, skip package manager
#   ./install.sh --help       # this help
#
# What it does:
#   1. Detects distro (Arch/CachyOS, Debian/Ubuntu, Fedora)
#   2. Installs: mango(compositor), waybar, swaync, rofi, foot/alacritty/kitty,
#      btop, grim, slurp, wl-clipboard + portals. All lightweight native
#      Wayland apps -- no Electron, no KDE/GNOME services.
#   3. Backs up your existing configs to ~/.config-backup-<timestamp>
#   4. Copies (or symlinks) dotfiles from ./dotfiles into $HOME
#
# Safe to re-run: it never deletes, only backs up and overwrites.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$REPO_DIR/dotfiles"
MODE="copy"
ASSUME_YES=0
INSTALL_PKGS=1

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    !! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --link) MODE="link" ;;
        --copy) MODE="copy" ;;
        --yes|-y) ASSUME_YES=1 ;;
        --no-packages) INSTALL_PKGS=0 ;;
        --help|-h) usage ;;
        *) die "unknown arg: $arg (try --help)" ;;
    esac
done

[ -d "$DOTFILES" ] || die "dotfiles dir not found: $DOTFILES (run from repo root)"

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    printf '%s [y/N] ' "$*"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# 1. Distro detection
# ---------------------------------------------------------------------------
DISTRO="unknown"
LIKE=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="${ID:-unknown}"
    LIKE="${ID_LIKE:-}"
fi
say "Distro: $DISTRO (like: ${LIKE:-n/a}) | mode: $MODE | packages: $([ "$INSTALL_PKGS" -eq 1 ] && echo yes || echo no)"

# ---------------------------------------------------------------------------
# 2. Package install
# ---------------------------------------------------------------------------
install_arch() {
    # CachyOS ships mangowm in its repos; vanilla Arch has it in the AUR.
    local pkgs=(waybar swaync rofi-wayland foot alacritty kitty btop grim slurp
                wl-clipboard wlr-randr xdg-desktop-portal-wlr xdg-desktop-portal-gtk
                polkit-gnome ttf-jetbrains-mono-nerd fastfetch)
    local mango_ok=0

    say "Installing packages (pacman)..."
    if command -v pacman >/dev/null; then
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" || warn "some pacman packages failed -- continuing"
        # mango: repo first, AUR second, source last
        if sudo pacman -S --needed --noconfirm mangowm 2>/dev/null; then
            mango_ok=1
        else
            info "mangowm not in repos -- trying AUR helper..."
            if command -v yay >/dev/null; then
                yay -S --needed --noconfirm mangowm && mango_ok=1 || true
            elif command -v paru >/dev/null; then
                paru -S --needed --noconfirm mangowm && mango_ok=1 || true
            else
                warn "no AUR helper (yay/paru). Install one, or mango will be built from source below."
            fi
        fi
    else
        warn "pacman not found despite Arch-like distro?"
    fi
    [ "$mango_ok" -eq 1 ] || build_mango_from_source
}

install_debian() {
    say "Installing packages (apt)..."
    sudo apt update
    # NOTE: Debian/Ubuntu have no mango package -> built from source below.
    # rofi on Wayland: bookworm+ ships rofi-wayland; older releases: plain rofi.
    local pkgs=(waybar sway-notification-center rofi foot alacritty kitty btop grim slurp
                wl-clipboard wlr-randr xdg-desktop-portal-wlr xdg-desktop-portal-gtk
                policykit-1-gnome fonts-jetbrains-mono fastfetch git curl)
    if apt-cache show rofi-wayland >/dev/null 2>&1; then
        pkgs+=(rofi-wayland)
    fi
    # sway-notification-center is the package name for swaync on Debian/Ubuntu
    sudo apt install -y "${pkgs[@]}" || warn "some apt packages failed -- continuing"
    build_mango_from_source
}

install_fedora() {
    say "Installing packages (dnf)..."
    sudo dnf install -y waybar swaync rofi foot alacritty kitty btop grim slurp \
        wl-clipboard wlr-randr xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        polkit-gnome jetbrains-mono-fonts-all fastfetch git curl \
        || warn "some dnf packages failed -- continuing"
    build_mango_from_source
}

build_mango_from_source() {
    command -v mango >/dev/null && { info "mango already installed: $(command -v mango)"; return 0; }
    say "Building mango compositor from source..."
    say "(upstream: https://github.com/DreamMaoMao/mango)"
    confirm "Build + sudo-install mango from source?" || { warn "skipping mango build -- compositor stays uninstalled"; return 0; }
    case "$DISTRO" in
        *debian*|*ubuntu*|*mint*|*pop*)
            sudo apt install -y git build-essential meson ninja-build scdoc \
                libwayland-dev wayland-protocols libinput-dev libdrm-dev libcairo2-dev \
                libpango1.0-dev libdisplay-info-dev libliftoff-dev libxkbcommon-dev \
                libxcb-composite0-dev libxcb-icccm4-dev libxcb-res0-dev \
                libwlroots-dev libscenefx-dev libcjson-dev seatd xwayland 2>/dev/null \
                || warn "some build deps failed -- build may still work if wlroots/scenefx present"
            ;;
        *fedora*)
            sudo dnf install -y git gcc meson ninja-build scdoc wayland-devel \
                wayland-protocols-devel libinput-devel libdrm-devel cairo-devel \
                pango-devel libdisplay-info-devel libliftoff-devel libxkbcommon-devel \
                wlroots-devel scenefx-devel cjson-devel seatd xorg-x11-server-Xwayland 2>/dev/null \
                || warn "some build deps failed -- continuing anyway"
            ;;
        *)
            sudo pacman -S --needed --noconfirm base-devel meson ninja scdoc git \
                wayland-protocols libinput libdrm cairo pango libdisplay-info libliftoff \
                seatd xorg-xwayland libxkbcommon wlroots0.20 scenefx cjson 2>/dev/null \
                || warn "some build deps failed -- continuing anyway"
            ;;
    esac
    local tmp; tmp="$(mktemp -d)"
    git clone --depth=1 https://github.com/DreamMaoMao/mango.git "$tmp/mango"
    (cd "$tmp/mango" && make && sudo make install) \
        || die "mango build failed -- see https://github.com/DreamMaoMao/mango for deps"
    rm -rf "$tmp"
    info "mango installed to /usr/local/bin/mango (make sure /usr/local/bin is in PATH)"
}

if [ "$INSTALL_PKGS" -eq 1 ]; then
    case "$DISTRO $LIKE" in
        *arch*|*cachyos*|*endeavour*|*manjaro*) install_arch ;;
        *debian*|*ubuntu*|*mint*|*pop*)         install_debian ;;
        *fedora*|*nobara*)                      install_fedora ;;
        *) warn "unknown distro '$DISTRO' -- skipping package install (use --no-packages + install manually)";;
    esac
else
    info "skipping package install (--no-packages)"
fi

# ---------------------------------------------------------------------------
# 3. Backup + install dotfiles
# ---------------------------------------------------------------------------
say "Installing dotfiles ($MODE mode)..."
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config-backup-$STAMP"
BACKED_UP=0

backup_if_exists() {
    local dest="$1"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mkdir -p "$BACKUP"
        local rel="${dest#$HOME/}"
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$dest" "$BACKUP/$rel"
        BACKED_UP=1
        info "backed up $dest"
    fi
}

install_one() { # install_one <src> <dest>
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ "$MODE" = "link" ]; then
        backup_if_exists "$dest"
        rm -rf "$dest"
        ln -s "$src" "$dest"
        info "linked $dest -> $src"
    else
        backup_if_exists "$dest"
        if [ -d "$src" ] && [ ! -L "$src" ]; then
            mkdir -p "$dest"
            cp -a "$src/." "$dest/"
        else
            cp -a "$src" "$dest"
        fi
        info "copied $src -> $dest"
    fi
}

# Top-level entries shipped in ./dotfiles (mirrors $HOME layout).
# Walk file-by-file (not whole dirs) so we never wipe ~/.local/share etc.,
# and so copy mode yields an exact mirror of what's in the repo.
while IFS= read -r src; do
    rel="${src#$DOTFILES/}"
    dest="$HOME/$rel"
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        mkdir -p "$dest"
    else
        install_one "$src" "$dest"
    fi
done < <(find "$DOTFILES" -mindepth 1 | sort)

chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
[ "$BACKED_UP" -eq 1 ] && info "old configs saved in $BACKUP" || info "nothing to back up (fresh install)"

# ---------------------------------------------------------------------------
# 4. Post-install notes (incl. why idle RAM was high + how to stay light)
# ---------------------------------------------------------------------------
say "Done!"
cat <<'EOF'
  Next steps:
    1. Log out, and at the login screen (SDDM/GDM/greetd) pick "mango" as
       the session. If mango is missing from the list, this file starts it:
         mango  (run from a TTY)
    2. Inside mango: Alt+Enter = terminal, Alt+Space = app launcher (rofi),
       Super+R = reload config after editing ~/.config/mango/config.conf
    3. Waybar reloads with:  pkill waybar; waybar &

  Why your idle RAM was 1.6 GB (and how this fixes it):
    - The compositor almost never matters. mango itself is ~90 MB; GNOME or
      KDE is 600-900 MB before you open anything. That swap alone saves ~0.5 GB.
    - The usual hogs are apps running at login: Discord/Slack/Spotify
      (~300-700 MB each, Electron), browser with many tabs (~200 MB/tab),
      file-indexers (baloo/tracker), snapd, docker,VM services, and tray apps.
      Check with:  btop   (or)   ps aux --sort=-%mem | head -15
    - Light swaps in this repo: foot (~15 MB) instead of GNOME Terminal/
      Konsole, rofi instead of full app grids, swaync instead of GNOME
      notifications, pipewire+wireplumber (already default on modern distros).
    - Keep autostart empty: no Discord/Steam/Spotify on login. Start them
      only when needed, and prefer the browser (1 tab) over the Electron app.
    - Fonts: install a Nerd Font or waybar shows boxes:
        Arch:   sudo pacman -S ttf-jetbrains-mono-nerd
        Ubuntu: sudo apt install fonts-jetbrains-mono  (then set your
                terminal font to it; waybar falls back to monospace anyway)

  Verify it worked:
    free -h          # idle desktop should sit ~500-800 MB, not 1.6 GB
    mango -v         # compositor version
    waybar -v; rofi -v; foot --version

  Your old configs (if any) were left in ~/.config-backup-<date> -- delete
  that folder once you're happy.
EOF
