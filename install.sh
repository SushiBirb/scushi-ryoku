#!/usr/bin/env bash
# ==============================================================================
# scushi-ryoku: Dotfiles & Customization Deployment Script
# ==============================================================================
# Deploys Scushi's custom configurations to ~/.config with automatic backups.
# Supports both dry-run and live symlink/copy modes.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
BACKUP_DIR="$HOME/.config/ryoku-dotfiles-backup-$(date +%Y%m%d_%H%M%S)"

DRY_RUN=false
SYMLINK_MODE=true

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --copy|-c)
            SYMLINK_MODE=false
            ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Preview actions without modifying files"
            echo "  --copy, -c       Copy files instead of symlinking"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

echo "========================================================================"
echo " scushi-ryoku: Deploying Dotfiles & Desktop Customizations"
echo "========================================================================"
echo " Source: $DOTFILES_DIR"
echo " Target: $HOME/.config"
if [ "$DRY_RUN" = true ]; then
    echo " Mode:   DRY RUN (no changes will be applied)"
elif [ "$SYMLINK_MODE" = true ]; then
    echo " Mode:   SYMLINK"
else
    echo " Mode:   COPY"
fi
echo "========================================================================"

mkdir -p "$BACKUP_DIR"

deploy_file() {
    local rel_path="$1"
    local src="$DOTFILES_DIR/$rel_path"
    local dest="$HOME/.config/$rel_path"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    if [ ! -f "$src" ]; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $src -> $dest"
        return
    fi

    mkdir -p "$dest_dir"

    # Backup existing file if present
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        local backup_dest="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_dest")"
        cp -P "$dest" "$backup_dest"
        rm -f "$dest"
    fi

    if [ "$SYMLINK_MODE" = true ]; then
        ln -sf "$src" "$dest"
        echo "[LINK]   $dest -> $src"
    else
        cp -P "$src" "$dest"
        echo "[COPY]   $src -> $dest"
    fi
}

# Deploy hyprland configurations
deploy_file "hypr/user.lua"
deploy_file "hypr/settings.lua"
deploy_file "hypr/rebinds.lua"
deploy_file "hypr/monitors.lua"
deploy_file "hypr/monitors_user.lua"
deploy_file "hypr/scripts/hyprsunset-scheduler.py"
deploy_file "hypr/scripts/user-autostart.sh"

# Deploy fish shell configurations
deploy_file "fish/user.fish"
deploy_file "fish/config.fish"

# Deploy kitty terminal configurations
deploy_file "kitty/user.conf"
deploy_file "kitty/kitty.conf"
deploy_file "kitty/current-theme.conf"

# Deploy fastfetch & btop
deploy_file "fastfetch/config.jsonc"
deploy_file "btop/btop.conf"

# Deploy neovim keymaps
deploy_file "nvim/lua/config/keymaps.lua"

# Deploy ghostty terminal
deploy_file "ghostty/config"
deploy_file "ghostty/ryoku-colors"

# Deploy quickshell patches
deploy_file "quickshell/shell/modules/desktop/Desktop.qml"
deploy_file "quickshell/shell/modules/visualizer/Visualizer.qml"
deploy_file "quickshell/reload-cover/assets/logo.png"

# Deploy qt6ct
deploy_file "qt6ct/qt6ct.conf"

# Deploy ryoku desktop and shell states
deploy_file "ryoku/desktop.json"
deploy_file "ryoku/theme.json"
deploy_file "ryoku/shell.json"
deploy_file "ryoku/matugen.json"

if [ "$DRY_RUN" = false ]; then
    chmod +x "$HOME/.config/hypr/scripts/hyprsunset-scheduler.py" 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/scripts/user-autostart.sh" 2>/dev/null || true

    # Clean up empty backup directory if nothing was backed up
    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        rmdir "$BACKUP_DIR"
    else
        echo ""
        echo " Backups created at: $BACKUP_DIR"
    fi

    echo ""
    echo " Deployment completed successfully!"
    echo " Reload Hyprland with:  hyprctl reload"
    echo " Reload Ryoku Shell with: ryoku reload"
fi
