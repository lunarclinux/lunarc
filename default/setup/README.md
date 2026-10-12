# First-login setup steps

`<id> setup welcome` (run once at first login, in its own window) runs every
`steps.d/*.sh` in name order. Each file is sourced in a subshell with the CLI
helpers (`lib.sh`, `ui.sh`) loaded and must define:

- `step_run` — shows the screen and does the work. `$STEP` and `$STEPS` hold
  the step's number and the count (for `ui_step "$STEP" "$STEPS" "Title"`).
  Return 0 to go on; any other status ends the setup early (it can be
  re-opened from the menu: Setup › Set up (the name)).

Optional:

- `# title: <words>` near the top — used in logs.
- `step_applies` — return non-zero to skip the step (it isn't counted).
- `step_skip` — run instead of `step_run` by `setup welcome --skip`
  (non-interactive: tests, or "skip all").

Numbering: 10 welcome, 20 backups, 30 display size, 50 privacy choices, 90 done. Add a step by
dropping a new file in between; nothing else needs changing.
