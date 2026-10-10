# title: Privacy choices
# shellcheck shell=bash
# The two things that are off by default but people often want: weather in the
# bar (sends your city name online) and encrypted DNS (sends your lookups to a
# provider you pick instead of the network's). Both stay off unless chosen
# here; both can be changed later with `<id> privacy`.

step_applies() { [[ -z $(setting privacy.asked) ]]; }

# Skipped: everything stays off.
step_skip() { set_setting privacy.asked skipped; }

privacy_choose() { # privacy_choose <option>... -> the chosen option
  if command -v gum >/dev/null; then
    gum choose "$@" || printf '%s\n' "${@: -1}"
  else
    local choice PS3="  Choose 1-$#: "
    select choice in "$@"; do break; done
    printf '%s\n' "${choice:-${*: -1}}"
  fi
}

step_run() {
  local choice
  ui_step "$STEP" "$STEPS" "Privacy"
  ui_text "$C_TEXT" "$DISTRO_NAME sends nothing about you anywhere: no telemetry, no usage statistics, nothing from the apps we include. Two optional things need the internet:"
  printf '\n'
  ui_text "$C_BOLD$C_TEXT" "Weather in the bar"
  ui_text "$C_MUTED" "Looks up your city (from your time zone) to show the weather. Only the city name is sent."
  printf '\n'
  choice=$(privacy_choose "Show the weather" "No weather")
  if [[ $choice == "Show the weather" ]]; then
    "/usr/bin/$DISTRO_ID" privacy weather on || true
  else
    "/usr/bin/$DISTRO_ID" privacy weather off >/dev/null || true
  fi

  ui_step "$STEP" "$STEPS" "Privacy"
  ui_text "$C_BOLD$C_TEXT" "Encrypted DNS"
  ui_text "$C_MUTED" "Every website name you visit is looked up through DNS. By default the network you're on (your router, internet provider, the café) sees those lookups unencrypted. You can send them encrypted to a provider instead. On Wi-Fi with a login page (hotels, airports) you may need to switch it off to sign in."
  printf '\n'
  choice=$(privacy_choose "Quad9 (Swiss non-profit, blocks known malware sites)" \
    "Mullvad (no logging, from the VPN company)" \
    "Cloudflare (fast, US company)" \
    "Keep the network's DNS")
  case $choice in
    Quad9*) "/usr/bin/$DISTRO_ID" privacy dns quad9 || true ;;
    Mullvad*) "/usr/bin/$DISTRO_ID" privacy dns mullvad || true ;;
    Cloudflare*) "/usr/bin/$DISTRO_ID" privacy dns cloudflare || true ;;
    *) : ;;
  esac
  set_setting privacy.asked yes
  printf '\n'
  ui_text "$C_MUTED" "Change these any time: '$DISTRO_ID privacy', or the menu's Setup › Privacy."
  ui_continue
}
