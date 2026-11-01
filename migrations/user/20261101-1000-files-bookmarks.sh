# shellcheck shell=bash
# Files' sidebar gets the standard folders (Documents, Downloads, Pictures,
# Music, Videos) as bookmarks, above any already there; new installs get them
# at first login. Folders already bookmarked are left alone. Runs once, so a
# bookmark removed later stays removed.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
files_bookmarks
