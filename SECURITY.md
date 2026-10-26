# Security policy

## Reporting a vulnerability

Please report security problems privately, not in public issues: use **Report a vulnerability** on the repository's Security tab (GitHub private vulnerability reporting), or email tyler@naturalstatetech.com.

Include what is affected (package, command or component, and its version: `pacman -Q <package>`), how to reproduce it, and what an attacker could do with it. Reports are acknowledged within a week; fixes ship as package updates through the distribution's repository.

## Scope

In scope: the distribution's own packages and tools (everything built from this repository), its installer and its default configuration. Problems in Arch Linux packages or upstream projects belong to those projects; reports that reach here are passed on.

## Supported versions

Only the current release is supported. Installs stay current through `<id> update` (or `pacman -Syu`).
