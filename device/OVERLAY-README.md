Device-specific rootfs overlay (copied into the device tarball as /system/...).
Empty on purpose for the first boot test; build.sh needs the directory to exist.
Later phases add here, modelled on ../../../q5q-port/ref/oneplus-salami/overlay: gbinder.conf, usb-moded,
ofono binder config, audiosystem-passthrough, libinput quirks.
