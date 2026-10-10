# shellcheck shell=bash
# The installer's look for desktop screens (first-login setup): Moonlit
# colours, the wordmark header and gum's widgets styled to match. Sourced by
# commands after lib.sh. The installer keeps its own copy (install/lib.sh),
# since it runs before this package is installed.

ui_init() {
  case $TERM in *ghostty*|*kitty*|*alacritty*|*wezterm*|foot*|*direct*) export COLORTERM=truecolor ;; esac
  GOLD='#EBC77A' TEXT='#E6E2D6' MUTED='#A3ABC4' SHADE='#2E3A5C' DARK='#0B1020'
  C_GOLD=$'\e[38;2;235;199;122m' C_TEXT=$'\e[38;2;230;226;214m' C_MUTED=$'\e[38;2;163;171;196m'
  C_GREEN=$'\e[38;2;159;212;154m' C_BOLD=$'\e[1m' C_OFF=$'\e[0m'
  export GUM_CHOOSE_CURSOR_FOREGROUND=$GOLD GUM_CHOOSE_HEADER_FOREGROUND=$MUTED
  export GUM_CHOOSE_SELECTED_FOREGROUND=$GOLD GUM_CHOOSE_ITEM_FOREGROUND=$TEXT
  export GUM_CHOOSE_CURSOR="› " GUM_CHOOSE_SHOW_HELP=false GUM_CHOOSE_HEADER="" GUM_CHOOSE_PADDING="0 2"
  export GUM_CONFIRM_PROMPT_FOREGROUND=$TEXT GUM_CONFIRM_SELECTED_FOREGROUND=$DARK
  export GUM_CONFIRM_SELECTED_BACKGROUND=$GOLD GUM_CONFIRM_UNSELECTED_FOREGROUND=$TEXT
  export GUM_CONFIRM_UNSELECTED_BACKGROUND=$SHADE GUM_CONFIRM_SHOW_HELP=false GUM_CONFIRM_PADDING="0 1"
  export GUM_INPUT_PROMPT_FOREGROUND=$GOLD GUM_INPUT_CURSOR_FOREGROUND=$GOLD
  export GUM_INPUT_PROMPT="› " GUM_INPUT_SHOW_HELP=false GUM_INPUT_PADDING="0 2"
}

# The top of every screen: the wordmark (its last letter gold, like the
# screensaver), or the name in a narrow window, then a subtitle.
ui_header() { # ui_header <subtitle>
  local art=$SHARE/default/screensaver/wordmark.txt line LC_ALL=C.UTF-8
  clear
  printf '\n'
  if [[ -f $art ]] && (( $(tput cols 2>/dev/null || echo 80) >= 58 )); then
    while IFS= read -r line; do
      printf '  %s%s%s%s%s\n' "$C_TEXT" "${line:0:43}" "$C_GOLD" "${line:43}" "$C_OFF"
    done < "$art"
  else
    printf '  %s%s%s%s\n' "$C_BOLD" "$C_GOLD" "$DISTRO_NAME" "$C_OFF"
  fi
  printf '\n  %s%s%s\n\n' "$C_TEXT" "$1" "$C_OFF"
}

# A step screen: header, "Step n of N" (when part of a sequence) and the title.
ui_step() { # ui_step <n> <of> <title>
  ui_header "Set up $DISTRO_NAME"
  if (( $2 > 1 )); then printf '  %sStep %s of %s%s\n' "$C_MUTED" "$1" "$2" "$C_OFF"; fi
  printf '  %s%s%s%s\n\n' "$C_BOLD" "$C_TEXT" "$3" "$C_OFF"
}

# A paragraph, wrapped to the window and indented like everything else.
ui_text() { # ui_text <colour> <text>
  local width
  width=$(( $(tput cols 2>/dev/null || echo 80) - 4 ))
  if (( width > 76 )); then width=76; fi
  fold -s -w "$width" <<<"$2" | sed "s/^/  $1/; s/\$/$C_OFF/"
}

# Press Enter to go on (the plain fallback when gum is missing).
ui_continue() { # ui_continue [label]
  printf '\n'
  if command -v gum >/dev/null; then
    gum choose "${1:-Continue}" >/dev/null || true
  else
    read -rp "  ${1:-Continue} (Enter) " _
  fi
}
