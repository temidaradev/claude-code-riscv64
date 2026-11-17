#!/bin/sh
# Run the latest official Claude Code on riscv64 Linux (Debian/Ubuntu family).
# Anthropic ships no riscv64 build, so this runs the linux-arm64 build under qemu-user.
# Nothing proprietary is stored here: the binary is fetched from npm at install time.
set -eu
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
[ "$(uname -m)" = riscv64 ] || { echo "this installer is for riscv64 hosts" >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
MIRROR=${DEBIAN_MIRROR:-https://deb.debian.org/debian}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# Newest trixie build of a package in the Debian pool.
latest_deb() { # <pool dir> <regex>
  curl -fsSL "$MIRROR/pool/main/$1/" | grep -oE "$2" | sort -uV | tail -1
}
fetch_deb() { # <pool dir> <file> <dest dir>
  curl -fsSL "$MIRROR/pool/main/$1/$2" -o "$T/$2"
  mkdir -p "$T/x" && (cd "$T/x" && ar x "$T/$2" && tar -xf data.tar.* -C "$3" && rm -f data.tar.* control.tar.* debian-binary)
}

echo ">> qemu-user (static, Debian trixie)"
# Distro qemu 7.x crashes running aarch64 binaries on riscv64 hosts; 10.x works.
Q=$(latest_deb q/qemu 'qemu-user_10\.0\.[0-9]+\+ds-0\+deb13u[0-9]+_riscv64\.deb')
mkdir -p "$T/q"; fetch_deb q/qemu "$Q" "$T/q"
install -m 755 "$T/q/usr/bin/qemu-aarch64" /usr/local/lib/qemu-aarch64

echo ">> aarch64 runtime libraries -> /usr/lib/aarch64-linux-gnu"
mkdir -p "$T/a64"
fetch_deb g/glibc "$(latest_deb g/glibc 'libc6_2\.41-[0-9]+\+deb13u[0-9]+_arm64\.deb')" "$T/a64"
fetch_deb g/gcc-14 "$(latest_deb g/gcc-14 'libgcc-s1_14\.2\.0-[0-9]+_arm64\.deb')" "$T/a64"
fetch_deb g/gcc-14 "$(latest_deb g/gcc-14 'libstdc\+\+6_14\.2\.0-[0-9]+_arm64\.deb')" "$T/a64"
mkdir -p /usr/lib/aarch64-linux-gnu
cp -a "$T/a64/usr/lib/aarch64-linux-gnu/." /usr/lib/aarch64-linux-gnu/
ln -sfn aarch64-linux-gnu/ld-linux-aarch64.so.1 /usr/lib/ld-linux-aarch64.so.1
[ -e /lib/ld-linux-aarch64.so.1 ] || ln -s /usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

echo ">> binfmt_misc registration (flags POCF)"
# P keeps argv[0], which Claude Code uses to run its bundled ripgrep; F pins the interpreter.
printf '%s\n' ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/local/lib/qemu-aarch64:POCF' > /etc/binfmt.d/qemu-aarch64.conf
[ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] && echo -1 > /proc/sys/fs/binfmt_misc/qemu-aarch64
systemctl restart systemd-binfmt

echo ">> Claude Code"
install -m 755 "$HERE/bin/claude" "$HERE/bin/claude-update" /usr/local/bin/
/usr/local/bin/claude-update
echo "done: run 'claude' (first start takes about a minute on a 1.5 GHz U74)"
