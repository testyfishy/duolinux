# Tailscale on the Duo Lite: blocked by the kernel

Status as of 2026-10-30: **installed but not usable in normal mode on this image.** The blocker is
in the kernel that ships with the device, not in the packaging.

## What the kernel provides

Running kernel: `7.2.0` (ROCKNIX SM6115 nightly).

```
$ zcat /proc/config.gz | grep -E "NF_TABLES|IP_NF_IPTABLES|IP_MULTIPLE_TABLES"
# CONFIG_NF_TABLES is not set
CONFIG_IP_NF_IPTABLES=m
```

```
$ ls /lib/modules/7.2.0/kernel/net/netfilter/
ipvs  nf_conntrack.ko  nf_log_syslog.ko  nf_nat.ko  x_tables.ko
xt_LOG.ko  xt_MASQUERADE.ko  xt_addrtype.ko  xt_conntrack.ko  xt_ipvs.ko
xt_mark.ko  xt_nat.ko  xt_tcpudp.ko
```

There is no `nf_tables.ko` (the option is off), and `ip_tables.ko` is not in the module tree even
though the config says `=m`, so neither backend can initialise:

```
$ iptables -L -n
iptables: Failed to initialize nft: Protocol not supported
$ nft list ruleset
src/mnl.c:64: Unable to initialize Netlink socket: Protocol not supported
```

`ip rule` is also unavailable (`CONFIG_IP_MULTIPLE_TABLES` is not set), so policy routing cannot be
used either.

## How that failure looks

`tailscaled` starts, creates its engine, then dies and is restarted by systemd until it gives up:

```
wgengine.NewUserspaceEngine(tun "tailscale0") ...
router: error querying IP rules (does kernel have IP_MULTIPLE_TABLES?): operation not supported
router: updateMagicsockPort(...) failed: could not setup netfilter: could not get iptables version
wgengine.NewUserspaceEngine(tun "tailscale0") error: router.Up: setting netfilter mode
tailscaled.service: Failed with result 'exit-code'
```

This is the same restart loop that caused Tailscale to be purged from the image earlier. Nothing in
userspace fixes it: the account, the binary and the repository are all fine.

## What does work

Userspace networking needs neither netfilter nor policy routing:

```sh
# /etc/default/tailscaled
FLAGS="--tun=userspace-networking --socks5-server=127.0.0.1:1055"
```

The daemon then stays up and can authenticate. The cost is that there is no `tailscale0` interface:
traffic does not route by tailnet IP, so plain `ssh 100.x.y.z` does not work. Only the SOCKS5 proxy,
`tailscale serve`/`funnel`, and `tailscale ssh`-style services within that model are usable.

## Options, in order of cost

1. **Rebuild the kernel with the features on.** Smallest set: `CONFIG_NF_TABLES=y` (or `=m` plus the
   module), `CONFIG_NF_TABLES_INET`, `CONFIG_IP_NF_IPTABLES=m` with `ip_tables.ko` actually shipped,
   and `CONFIG_IP_MULTIPLE_TABLES=y`. Then normal `--tun=tailscale0` works.
2. **Move to a newer kernel.** If a later ROCKNIX nightly enables netfilter tables (many handheld
   kernels do once Docker/containers are wanted), this resolves itself; check the config before
   flashing.
3. **Userspace networking.** Works now, but with the routing caveat above.
4. **Do not use Tailscale here.** Plain SSH over the LAN (or a reverse tunnel to a reachable host)
   already covers the KVM-terminal use case while the device is on the home network.

## Reproduce the diagnosis

```sh
zcat /proc/config.gz | grep -E "NF_TABLES|IP_NF_IPTABLES|IP_MULTIPLE_TABLES"
ls /lib/modules/$(uname -r)/kernel/net/netfilter/
iptables -L -n; nft list ruleset
timeout 5 tailscaled --state=/tmp/ts.state --socket=/tmp/ts.sock --port=0 --verbose=1
```

The last command prints the `router.Up: setting netfilter mode` error that tells you it is this
problem and not a credential or network issue.
