# title: Display size
# shellcheck shell=bash
# How big text and everything else looks on the screen. The size is chosen from
# the screen's dimensions; this shows the choices around it, applied straight
# away, and goes back if not kept within 10 seconds. Later: Setup › Display size,
# or `<id> display size`.

step_applies() { [[ -z $(setting display.asked) && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; }

step_skip() { set_setting display.asked skipped; }

step_run() {
  ui_step "$STEP" "$STEPS" "Display size"
  ui_text "$C_TEXT" "Make text and everything else on the screen bigger or smaller. Each choice is applied right away; keep it, or it goes back after 10 seconds."
  printf '\n'
  "/usr/bin/$DISTRO_ID" display size || true
  set_setting display.asked yes
  printf '\n'
  ui_text "$C_MUTED" "Change it any time: Setup › Display size in the menu, or '$DISTRO_ID display size'."
  ui_continue
}
