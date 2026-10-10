# title: Welcome
# shellcheck shell=bash
step_run() {
  ui_step "$STEP" "$STEPS" "Welcome"
  ui_text "$C_TEXT" "A few choices to finish setting up this computer. Each one can be changed later from the menu (SUPER+ALT+Space › Setup)."
  ui_continue "Start"
}
