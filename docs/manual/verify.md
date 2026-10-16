# Checking downloads

## The installer image

Each ISO is published with its SHA-256 checksum and a signature (`.sig`) made with
the Lunarc signing key. The checksum shows the file arrived intact; the signature
shows it was made by the key's owner.

The signing key's fingerprint is:

```
798A 81A8 9261 BC4E 49D0  784B FD4E E07A 81DE 46AE
```

Download the key (`lunarc-signing-key.asc`, from the website) and check its
fingerprint before trusting it:

```sh
gpg --show-keys lunarc-signing-key.asc
gpg --import lunarc-signing-key.asc
```

Then, in the folder with the ISO and its `.sig`:

```sh
sha256sum lunarc-YYYY.MM.DD-x86_64.iso
gpg --verify lunarc-YYYY.MM.DD-x86_64.iso.sig lunarc-YYYY.MM.DD-x86_64.iso
```

The checksum must match the one on the download page, and gpg must say
`Good signature from "Lunarc Package Signing"` with the fingerprint above. gpg also
warns that the key "is not certified with a trusted signature": that only means you
haven't signed the key yourself, and is expected.

On Windows, PowerShell prints the checksum with
`Get-FileHash .\lunarc-YYYY.MM.DD-x86_64.iso -Algorithm SHA256`; Gpg4win provides `gpg`.

## Packages

The same key signs Lunarc's packages and its package database. pacman refuses
packages from the Lunarc repository that aren't signed by it (`SigLevel = Required`).
An installed system gets the key from the `lunarc-keyring` package:
`pacman-key --list-keys 798A81A89261BC4E49D0784BFD4EE07A81DE46AE` shows it.
