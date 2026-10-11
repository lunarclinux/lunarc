# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). `<id> share` end to end against an NFS
# export on the VM itself (there's no NAS in the test): bad input refused with
# /etc/fstab untouched, then add → on-demand mount → write → folder for this
# computer → list/test → remove.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
id=@ID@
fail() { echo "share check: $*"; exit 1; }
u=$(id -u); g=$(id -g); me=$(id -un)
mp=/mnt/nas/$me/test
unit=$(systemd-escape --path --suffix=automount "$mp")

# A stand-in NAS: export a folder over NFS on 127.0.0.1, every request mapped
# to this user (like TrueNAS's Mapall).
sudo install -d -o "$u" -g "$g" /srv/share-test
sudo install -d /etc/exports.d
printf '/srv/share-test 127.0.0.1(rw,sync,no_subtree_check,all_squash,anonuid=%s,anongid=%s)\n' "$u" "$g" \
  | sudo tee /etc/exports.d/share-test.exports >/dev/null
sudo systemctl start nfs-server >/dev/null 2>&1 || fail "NFS server didn't start"
sudo exportfs -ra
showmount -e 127.0.0.1 2>/dev/null | grep -q /srv/share-test || fail "showmount doesn't list the export"

# Bad input is refused before anything is written.
before=$(sha256sum /etc/fstab)
for bad in '1.2.3.4;rm:/x' '127.0.0.1:/a,b' '127.0.0.1:/a/../b' '127.0.0.1:/a b'; do
  if sudo "$id" share add --nfs "$bad" --name bad --yes >/dev/null 2>&1; then fail "accepted '$bad'"; fi
done
if sudo "/usr/lib/$id/share-helper" add-nfs bad '1.2.3.4;rm' /x >/dev/null 2>&1; then fail "helper accepted a bad host"; fi
if sudo "/usr/lib/$id/share-helper" add-nfs '../x' 127.0.0.1 /x >/dev/null 2>&1; then fail "helper accepted a bad name"; fi
# The helper takes its user from sudo/pkexec only, and never acts for root.
if sudo env -u SUDO_UID -u PKEXEC_UID "/usr/lib/$id/share-helper" add-nfs x 127.0.0.1 /x >/dev/null 2>&1; then fail "helper ran without a calling user"; fi
[ "$(sha256sum /etc/fstab)" = "$before" ] || fail "bad input changed /etc/fstab"

# Set up, mounted on demand.
sudo "$id" share add --nfs 127.0.0.1:/srv/share-test --name test --device testbox --yes >/dev/null || fail "add failed"
grep -qx "# $id share: $me/test" /etc/fstab || fail "no fstab entry"
entry=$(grep -A1 -x "# $id share: $me/test" /etc/fstab | tail -1)
for opt in nosuid nodev noexec; do
  case ",$(awk '{print $4}' <<<"$entry")," in *",$opt,"*) ;; *) fail "mount option $opt missing: $entry" ;; esac
done
case $entry in *x-systemd.automount*) ;; *) fail "not mounted on demand: $entry" ;; esac
case $entry in *nofail*) ;; *) fail "could block boot: $entry" ;; esac
systemctl is-active --quiet "$unit" || fail "automount not active ($unit)"
[ "$(stat -c '%a %U' "/mnt/nas/$me")" = "700 $me" ] || fail "/mnt/nas/$me isn't 0700 and mine"
[ -d "$mp/testbox" ] || fail "no folder for this computer"
findmnt -n -t nfs,nfs4 "$mp" >/dev/null || fail "not mounted after use"
case ",$(findmnt -no OPTIONS "$mp")," in *,nosuid,*nodev,*noexec,*) ;; *) fail "mounted without nosuid/nodev/noexec: $(findmnt -no OPTIONS "$mp")" ;; esac
touch "$mp/testbox/probe" && rm "$mp/testbox/probe" || fail "can't write"
# Another local user can't look in.
sudo useradd -m sharecheck2 >/dev/null 2>&1 || true
if sudo -u sharecheck2 ls "$mp" >/dev/null 2>&1; then fail "another user can list the share"; fi
sudo userdel -r sharecheck2 >/dev/null 2>&1 || true
"$id" share list | grep -q '^test ' || fail "list doesn't show it"
"$id" share test test >/dev/null || fail "share test failed"

# Remove.
sudo "$id" share remove test >/dev/null || fail "remove failed"
if grep -q "# $id share: $me/test" /etc/fstab; then fail "fstab entry left behind"; fi
if systemctl is-active --quiet "$unit"; then fail "automount left behind"; fi
sudo rm -f /etc/exports.d/share-test.exports
sudo exportfs -ra
exit 0
