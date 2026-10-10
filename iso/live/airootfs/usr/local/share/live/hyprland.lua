-- Live system only: the installer covers the whole screen.
hl.window_rule({
    name = "installer",
    match = { class = "^@DISTRO_ID@\\.installer$" },
    fullscreen = true,
})
