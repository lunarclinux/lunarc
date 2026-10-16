# shellcheck shell=bash
# Installs that ran Arch's Noctalia before the distro's own build (an older
# release, the one the distro is tested with) have its settings file written
# by the newer release: "config_version: version 15 is newer than supported
# version 14". Noctalia then ignores the whole file (the theme and wallpaper
# chosen in its settings) and `noctalia config export` fails. Mark each such
# file with the version this Noctalia reads, keeping a copy as it was;
# settings it doesn't know are only warned about. Safe to run again.
command -v noctalia >/dev/null || exit 0
changed=0
out=$(noctalia config validate 2>&1 || true)
while read -r file have want; do
  [[ -f $file && $file == "$HOME"/* ]] || continue
  cp -p "$file" "$file.v$have"
  sed -i -E "s/^config_version[[:space:]]*=[[:space:]]*$have\$/config_version = $want/" "$file"
  echo "Noctalia's $(basename "$file") was written by a newer Noctalia; kept a copy as $(basename "$file").v$have"
  changed=1
done < <(sed -nE 's/^ERROR (.*):[0-9]+:[0-9]+: config_version: version ([0-9]+) is newer than supported version ([0-9]+).*/\1 \2 \3/p' <<<"$out")
if (( changed )); then noctalia msg config-reload >/dev/null 2>&1 || true; fi
