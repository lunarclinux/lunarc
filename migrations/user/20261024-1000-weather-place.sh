# shellcheck shell=bash
# Weather's place came from the time zone's last part, so an old zone name such
# as US/Central asked for a place called "Central". Rewrite the weather block
# with the real zone's city (America/Chicago -> Chicago), only for people who
# have weather on and haven't chosen a place themselves.
out=$("/usr/bin/@DISTRO_ID@" privacy weather 2>/dev/null) || exit 0
[[ $out == "weather: on"* ]] || exit 0
config=${XDG_CONFIG_HOME:-$HOME/.config}/@DISTRO_ID@/settings
if [[ -f $config ]] && grep -q '^privacy.weather_location *=' "$config"; then exit 0; fi
"/usr/bin/@DISTRO_ID@" privacy weather location time-zone >/dev/null 2>&1 || true
