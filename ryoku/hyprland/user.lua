-- --- hypr/user.lua --------------------------------------------------------
-- Your Hyprland overrides, in Ryoku's `hl` Lua API. Loaded LAST, so anything
-- here wins over Ryoku's defaults and over Ryoku Settings. Updates never touch
-- it. Reach for it only for raw config the GUI does not expose.

-- Environment variables
hl.env("GTK_IM_MODULE", "simple")

-- Crossfade HyprWpE wallpaper layer surfaces cleanly (suppress popin flicker)
hl.layer_rule({
  name      = "hyprwpe-crossfade",
  match     = { namespace = "^(hyprwpe-web|hyprwpe-viewer)$" },
  animation = "fade",
})

-- Monitor -> default workspace bindings
hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })

-- Games -> workspace 5 (takes focus)
hl.window_rule({ match = { class = "^steam_app_.*$" }, workspace = "5" })
hl.window_rule({ match = { class = "^[Ss]pider-?[Mm]an.*$" }, workspace = "5" })
hl.window_rule({ match = { class = "^sober$" }, workspace = "5" })
hl.window_rule({ match = { class = "^org\\.vinegarhq\\.Sober$" }, workspace = "5" })

-- Silent apps -> designated workspaces
hl.window_rule({ match = { class = "^[Ss]team.*$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^[Zz]en.*$" }, workspace = "1 silent", opaque = true })
hl.window_rule({ match = { class = "^[Dd]iscord.*$" }, workspace = "2 silent", opaque = true })
hl.window_rule({ match = { class = "^[Ss]one.*$" }, workspace = "10 silent", opaque = true })

-- Force fully opaque (no inactive transparency) for Zen, Discord, and Sone
hl.window_rule({ match = { class = "^[Zz]en.*$" }, opaque = true })
hl.window_rule({ match = { class = "^[Dd]iscord.*$" }, opaque = true })
hl.window_rule({ match = { class = "^[Ss]one.*$" }, opaque = true })

-- Focus follows mouse hover (persistent enforcement)
-- Synchronizes with Ryoku Settings (desktop.json) and ensures windows focus under
-- cursor even if external games, wine/proton, or runtime events change follow_mouse.
local desired_follow_mouse = 1

local function update_desired_follow_mouse()
    local home = os.getenv("HOME") or ""
    local f = io.open(home .. "/.config/ryoku/desktop.json", "r")
    if f then
        local content = f:read("*a")
        f:close()
        local fm = content:match('"followMouse"%s*:%s*(%d+)')
        if fm then
            desired_follow_mouse = tonumber(fm)
        end
    end
end

local function enforce_follow_mouse()
    if hl.get_config("input:follow_mouse") ~= desired_follow_mouse then
        hl.config({ input = { follow_mouse = desired_follow_mouse } })
    end
end

update_desired_follow_mouse()
enforce_follow_mouse()

hl.on("hyprland.start", function()
    update_desired_follow_mouse()
    enforce_follow_mouse()
end)

hl.on("config.reloaded", function()
    update_desired_follow_mouse()
    enforce_follow_mouse()
end)

hl.on("config.props_refreshed", enforce_follow_mouse)
hl.on("workspace.active", enforce_follow_mouse)
hl.timer(enforce_follow_mouse, { timeout = 2500, type = "repeat" })


-- Tap Super (Windows key) alone to open the app launcher
hl.bind("SUPER + Super_L", hl.dsp.global("ryoku:launcher"), { release = true })
hl.bind("SUPER + Super_R", hl.dsp.global("ryoku:launcher"), { release = true })
hl.bind("Super_L", hl.dsp.global("ryoku:launcher"), { release = true })
hl.bind("Super_R", hl.dsp.global("ryoku:launcher"), { release = true })

-- Scratchpad workspace
local ws_helper = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/ryoku-workspace"
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratch"), { description = "Toggle scratchpad workspace" })
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd(ws_helper .. " hide"), { description = "Stash focused window to/from scratchpad" })

-- Keybind to edit user configuration
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/user.lua"), { description = "Edit user overrides" })

-- Toggle night light manually (Super + U)
hl.bind("SUPER + U", hl.dsp.exec_cmd("ryoku-cmd-nightlight toggle"), { description = "Toggle night light" })

-- Autostart user apps
hl.on("hyprland.start", function()
    local autostart_script = (os.getenv("HOME") or "") .. "/.config/hypr/scripts/user-autostart.sh"
    hl.exec_cmd(autostart_script)
end)

-- Disable PlayStation / DualShock / DualSense controller touchpad from acting as desktop mouse
hl.device({ name = "wireless-controller-touchpad", enabled = false })
hl.device({ name = "sony-interactive-entertainment-wireless-controller-touchpad", enabled = false })
hl.device({ name = "sony-interactive-entertainment-dualsense-wireless-controller-touchpad", enabled = false })



