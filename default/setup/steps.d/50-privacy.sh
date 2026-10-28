# title: Privacy choices
# shellcheck shell=bash
# The things that are off by default but people often want: weather in the
# bar (sends your city name online), encrypted DNS (sends your lookups to a
# provider you pick instead of the network's) and a daily update check
# (downloads the package lists). All stay off unless chosen here; all can be
# changed later (`<id> privacy`, `<id> update auto-check`).

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
  ui_text "$C_TEXT" "$DISTRO_NAME itself collects nothing and tracks nothing. The apps it includes keep their makers' settings: Firefox's data collection, for one, is turned off in Firefox Settings › Privacy & Security. Three optional things need the internet:"
  printf '\n'
  local zone city
  zone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  # Old names (US/Central) are links to the real zone (America/Chicago).
  city=$(awk -v z="$zone" '$1 == "L" && $3 == z { print $2; exit }' /usr/share/zoneinfo/tzdata.zi 2>/dev/null || true)
  zone=${city:-$zone}; city=${zone##*/}; city=${city//_/ }
  ui_text "$C_BOLD$C_TEXT" "Weather in the bar"
  ui_text "$C_MUTED" "Shows the forecast for a place. The place name is looked up online (only the name is sent); coordinates skip that lookup; finding it from your internet address asks a location service."
  printf '\n'
  choice=$(privacy_choose "Weather for my time zone's city${city:+ ($city)}" "Weather for a city I type" \
    "Weather for exact coordinates" "Weather for where my internet address says I am" "No weather")
  case $choice in
    *"time zone"*) "/usr/bin/$DISTRO_ID" privacy weather location time-zone >/dev/null || true ;;
    *"city I type"*)
      if command -v gum >/dev/null; then city=$(gum input --header "City (e.g. Little Rock, AR)" --placeholder "City" || true)
      else read -rp "  City (e.g. Little Rock, AR): " city || city=""; fi
      if [[ -n $city ]]; then "/usr/bin/$DISTRO_ID" privacy weather location "$city" >/dev/null || choice="No weather"; else choice="No weather"; fi ;;
    *coordinates*)
      if command -v gum >/dev/null; then city=$(gum input --header "Latitude,longitude (e.g. 34.75,-92.29)" --placeholder "lat,lon" || true)
      else read -rp "  Latitude,longitude: " city || city=""; fi
      if [[ -n $city ]]; then "/usr/bin/$DISTRO_ID" privacy weather location "$city" >/dev/null || choice="No weather"; else choice="No weather"; fi ;;
    *"internet address"*) "/usr/bin/$DISTRO_ID" privacy weather location auto >/dev/null || true ;;
  esac
  if [[ $choice == "No weather" ]]; then
    "/usr/bin/$DISTRO_ID" privacy weather off >/dev/null || true
  else
    "/usr/bin/$DISTRO_ID" privacy weather on || true
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

  ui_step "$STEP" "$STEPS" "Privacy"
  ui_text "$C_BOLD$C_TEXT" "Checking for updates"
  ui_text "$C_MUTED" "Once a day, download the package lists from the Arch and $DISTRO_NAME package servers to see what's waiting. Nothing is installed; the menu shows the count."
  printf '\n'
  choice=$(privacy_choose "Check daily" "Only when I ask")
  if [[ $choice == "Check daily" ]]; then
    "/usr/bin/$DISTRO_ID" update auto-check on || true
  fi
  set_setting privacy.asked yes
  printf '\n'
  ui_text "$C_MUTED" "Change these any time: '$DISTRO_ID privacy' (and '$DISTRO_ID privacy weather location' for the place) and '$DISTRO_ID update auto-check', or the menu's Setup › Privacy, Setup › Weather location and System › Check for updates daily."
  ui_continue
}
