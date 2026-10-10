# title: Done
# shellcheck shell=bash
step_run() {
  ui_step "$STEP" "$STEPS" "That's it"
  ui_text "$C_TEXT" "SUPER+ALT+Space opens the menu, SUPER+Space your apps, SUPER+Return a terminal and SUPER+K every shortcut."
  ui_continue "Close"
}
