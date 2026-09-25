-- Hyprland for the login screen (greetd, runs as the `greeter` user).
-- install.sh copies this to /etc/greetd/hyprland.lua and the greeter QML
-- (greeter/*.qml + shared files from config/quickshell) to /etc/greetd/quickshell.
-- greetd starts the real session once this compositor exits, so exit when qs does.

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Theme.qml reads this instead of ~/Pictures/Wallpapers (the greeter can't read $HOME)
hl.env("QS_WALLPAPER", "/usr/local/share/wallpapers/shizuku-monochrome-4k.mp4")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function ()
    hl.exec_cmd("qs -p /etc/greetd/quickshell; hyprctl dispatch 'hl.dsp.exit()'")
end)

hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,
    },

    animations = {
        enabled = true,
    },

    misc = {
        force_default_wallpaper = 0,
        background_color        = 0x000000, -- black until qs draws the wallpaper
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
    },

    ecosystem = {
        no_update_news   = true,
        no_donation_nag  = true,
    },

    input = {
        kb_layout = "us",
        numlock_by_default = true,
        follow_mouse = 1,
        accel_profile = "flat",
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.animation({ leaf = "global",   enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4,  bezier = "easeOutQuint", style = "fade" })

-- The login box has its own glitch in/out
hl.layer_rule({
    name    = "greeter-no-anim",
    match   = { namespace = "^quickshell-greeter$" },
    no_anim = true,
})
