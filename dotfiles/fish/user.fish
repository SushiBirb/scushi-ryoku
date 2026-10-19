# User fish configuration (loaded last by config.fish)

# Atuin shell history
if status is-interactive
    if command -v atuin >/dev/null 2>&1
        atuin init fish | source
    end

    # Custom aliases & typo helpers
    alias pamcan pacman
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
end
