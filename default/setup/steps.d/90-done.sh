# title: Done
# shellcheck shell=bash
step_run() {
  ui_step "$STEP" "$STEPS" "That's it"
  ui_text "$C_TEXT" "SUPER+Space opens your apps and the menu, SUPER+Return a terminal and SUPER+K every shortcut."
  ui_continue "Close"
}
