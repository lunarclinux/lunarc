# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). `<id> share` end to end against an NFS
# export on the VM itself (there's no NAS in the test): bad input refused with
# /etc/fstab untouched, then add → on-demand mount → write → folder for this
# computer → list/test → remove.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
id=@ID@
fail() { echo "share check: $*"; exit 1; }
u=$(id -u); g=$(id -g)

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
[ "$(sha256sum /etc/fstab)" = "$before" ] || fail "bad input changed /etc/fstab"

# Set up, mounted on demand.
sudo "$id" share add --nfs 127.0.0.1:/srv/share-test --name test --device testbox --yes >/dev/null || fail "add failed"
grep -qx "# $id share: test" /etc/fstab || fail "no fstab entry"
entry=$(grep -A1 -x "# $id share: test" /etc/fstab | tail -1)
case $entry in *x-systemd.automount*) ;; *) fail "not mounted on demand: $entry" ;; esac
case $entry in *nofail*) ;; *) fail "could block boot: $entry" ;; esac
systemctl is-active --quiet mnt-nas-test.automount || fail "automount not active"
[ -d /mnt/nas/test/testbox ] || fail "no folder for this computer"
findmnt -n -t nfs,nfs4 /mnt/nas/test >/dev/null || fail "not mounted after use"
touch /mnt/nas/test/testbox/probe && rm /mnt/nas/test/testbox/probe || fail "can't write"
"$id" share list | grep -q '^test ' || fail "list doesn't show it"
"$id" share test test >/dev/null || fail "share test failed"

# Remove.
sudo "$id" share remove test >/dev/null || fail "remove failed"
if grep -q "# $id share: test" /etc/fstab; then fail "fstab entry left behind"; fi
if systemctl is-active --quiet mnt-nas-test.automount; then fail "automount left behind"; fi
sudo rm -f /etc/exports.d/share-test.exports
sudo exportfs -ra
exit 0
