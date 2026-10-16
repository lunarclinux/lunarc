# shellcheck shell=bash
# The shell no longer downloads its community palette list or community
# templates unless they're used (decision record 0031, 2026-10-16), but
# installs that ran an earlier Noctalia still keep what it fetched in
# ~/.local/state/noctalia. Remove those caches unless the palette source is
# "community" or community templates are on (then they're in use and stay).
command -v noctalia >/dev/null || exit 0
state=${NOCTALIA_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/noctalia}
config=$(noctalia config export 2>/dev/null || true)
if ! grep -qE '^[[:space:]]*source[[:space:]]*=[[:space:]]*"community"' <<<"$config"; then
  rm -rf "$state/community-palettes"
fi
if ! grep -qE '^[[:space:]]*enable_community_templates[[:space:]]*=[[:space:]]*true' <<<"$config"; then
  rm -rf "$state/community-templates"
fi
