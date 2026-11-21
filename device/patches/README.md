# Kernel patches

These patches modify the Linux kernel and are licensed under **GPL-2.0-only**, the same license as the code they
change. The repository's MIT license (`../../LICENSE`) does not apply to the files in this directory.

- `0001-wait-introduce-waitid-P_PIDFD.patch`: backport of `waitid(P_PIDFD)` (Linux 5.4) to the 4.19 tree
- `0002-apparmor-set-peer-label-on-unix-stream-connect.patch`: record AF_UNIX peer labels so `SO_PEERSEC` works
