# shellcheck shell=bash
# Installs made before 2026-10-11 kept the install medium's copy of the
# distro repository's database, which doesn't match the server's signature
# ("signature is invalid" on update). Remove it if its signature doesn't
# check out; the next update downloads a matching pair.
repo=$DISTRO_REPO
sync=/var/lib/pacman/sync
[[ -f $sync/$repo.db ]] || exit 0
if [[ ! -f $sync/$repo.db.sig ]] || ! pacman-key --verify "$sync/$repo.db.sig" "$sync/$repo.db" >/dev/null 2>&1; then
  rm -f "$sync/$repo".{db,files}{,.sig}
fi
