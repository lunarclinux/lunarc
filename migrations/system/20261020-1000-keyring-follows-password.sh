# shellcheck shell=bash
# Changing your login password with `passwd` changes the keyring's password
# too (passwords saved by browsers and apps). Without this the keyring kept
# the old password, so a password login stopped unlocking it. A keyring with
# no password of its own (encrypted disk with automatic login, decision record
# 0047) stays as it is. /etc/pam.d/passwd is a pacman backup file, so the line
# survives updates. New installs get this from the installer, which runs this
# file. Safe to run again.
pam=/etc/pam.d/passwd
[[ -f $pam && -f /usr/lib/security/pam_gnome_keyring.so ]] || exit 0
grep -q pam_gnome_keyring "$pam" && exit 0
printf 'password\toptional\tpam_gnome_keyring.so\n' >> "$pam"
