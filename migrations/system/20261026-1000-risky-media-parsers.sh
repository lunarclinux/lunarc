# shellcheck shell=bash
# Leaves out four file-format parsers with unfixed memory-safety bugs that no
# default app needs: GStreamer's modplug (tracker music: .mod, .s3m, .dsm…),
# gme (console music: .nsf, .ay, .gbs…) and wildmidi (MIDI) plugins, and the
# search indexer's XPS extractor (it reads files in Downloads on its own).
# A NoExtract line in /etc/pacman.conf keeps package updates from putting
# them back; the files already installed are removed now. To have them back:
# delete the marked lines from /etc/pacman.conf and reinstall gst-plugins-bad
# and localsearch. Safe to run again.
conf=/etc/pacman.conf
files="usr/lib/gstreamer-1.0/libgstmodplug.so usr/lib/gstreamer-1.0/libgstgme.so usr/lib/gstreamer-1.0/libgstwildmidi.so usr/lib/localsearch-3.0/extract-modules/libextract-xps.so usr/share/localsearch3/extract-rules/10-xps.rule"
marker="# @DISTRO_ID@: parsers left out (risky formats; see the manual's apps page)"
if [[ -f $conf ]] && ! grep -qxF "$marker" "$conf" && grep -q '^\[options\]' "$conf"; then
  tmp=$(mktemp /etc/.pacman.conf.XXXXXX)
  awk -v m="$marker" -v f="$files" '{ print } /^\[options\]$/ && !done { print m; print "NoExtract = " f; done = 1 }' "$conf" > "$tmp"
  # Exactly two lines more, nothing else changed; otherwise leave it alone.
  if [[ $(( $(wc -l < "$tmp") - $(wc -l < "$conf") )) -eq 2 ]] && diff <(grep -vxF "$marker" "$tmp" | grep -vx "NoExtract = $files") "$conf" >/dev/null; then
    chmod --reference="$conf" "$tmp"; mv "$tmp" "$conf"
  else
    rm -f "$tmp"
  fi
fi
for f in $files; do rm -f -- "/$f"; done
