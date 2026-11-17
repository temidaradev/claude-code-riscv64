# claude-code-riscv64

Run the latest official [Claude Code](https://code.claude.com) on riscv64 Linux.

Anthropic publishes Claude Code only for x86-64 and arm64. This repository
runs the official, unmodified **linux-arm64** build on riscv64 under
qemu-user, registered through binfmt_misc so `claude` behaves like a native
command.

No Claude Code binary is stored here. The installer downloads it from the npm
registry and verifies its published sha512 integrity hash.

Tested on a StarFive VisionFive 2 (JH7110, 4x SiFive U74, 8 GB) running
StarFive's Debian image (glibc 2.36).

## Install

```sh
git clone https://github.com/temidaradev/claude-code-riscv64
cd claude-code-riscv64
sudo ./install.sh
claude
```

The installer:

1. Installs a static **qemu-aarch64 10.x** from Debian trixie to
   `/usr/local/lib/qemu-aarch64`. The qemu 7.2 in older Debian releases crashes
   on aarch64 binaries running on riscv64 hosts.
2. Installs aarch64 glibc, libgcc and libstdc++ to the standard multiarch path,
   `/usr/lib/aarch64-linux-gnu`.
3. Registers qemu with binfmt_misc using flags `POCF`. `P` preserves `argv[0]`,
   which Claude Code relies on to run its bundled ripgrep.
4. Installs the `claude` and `claude-update` wrappers to `/usr/local/bin` and
   fetches the latest Claude Code.

## Update

```sh
claude-update            # latest
claude-update 2.1.326    # a specific version
```

The built-in auto-updater is disabled because it is unreliable under emulation.

## Performance

Expect about a minute to start on a 1.5 GHz U74. Once Claude Code is running,
it is usable but noticeably slower than native. The wrapper sets two options
that make the biggest difference:

| Setting | Why |
|---|---|
| `QEMU_CPU=neoverse-n1` | qemu's default `max` CPU emulates pointer authentication and SVE, which makes startup stall for minutes |
| `BUN_JSC_useDFGJIT=0` | less JIT output for qemu to translate, which is the dominant startup cost |

Both can be overridden from the environment.

## Troubleshooting

**"Unable to connect to Anthropic services"**: check `getent ahosts
api.anthropic.com`. If it takes seconds, or returns IPv6 addresses on a network
without IPv6 routing, prefer IPv4 and fix the resolver:

```sh
echo 'precedence ::ffff:0:0/96  100' | sudo tee -a /etc/gai.conf
sudo nmcli con mod "<connection>" ipv4.dns-options "single-request-reopen,timeout:2,attempts:2"
sudo nmcli dev reapply <iface>
```

## License

The scripts in this repository are MIT licensed. Claude Code itself is
proprietary Anthropic software, governed by
[Anthropic's terms](https://www.anthropic.com/legal/commercial-terms), and is
not redistributed here.
