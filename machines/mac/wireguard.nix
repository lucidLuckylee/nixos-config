{ config, pkgs, lib, ... }:

# WireGuard "home VPN" server on the Mac, managed by nix-darwin.
#
# Why here and not on the router: the o2 HomeBox 3 has no VPN server. It does
# have a public IPv4 (no carrier-grade NAT), port forwarding and DynDNS, which
# is all a self-hosted server needs. Clients get a 10.8.0.0/24 address, reach
# the home LAN (192.168.1.0/24) and, by default, route all traffic through
# home. NAT is done by macOS pf via an anchor under "com.apple/*", which the
# stock /etc/pf.conf already evaluates — no edit to pf.conf needed.
#
# One-time steps outside this file:
#   1. o2 box (http://o2.box): DHCP reservation for this Mac (192.168.1.190),
#      port forward UDP 51820 -> 192.168.1.190, and enable DynDNS. Put the
#      DynDNS hostname into `endpoint` below.
#   2. `update` (darwin-rebuild switch). The activation script generates the
#      server key at /etc/wireguard/server.key on first run — the key never
#      enters the Nix store or git; only the public key is derived from it.
#   3. `sudo wg-add-client <name>` per phone/laptop. It prints a client config
#      (and a QR code for the WireGuard mobile app) plus the `peers` entry to
#      paste below. Add it, `update` again. Peers are declarative on purpose:
#      whatever is listed here is exactly what can connect.
#
# Debugging: `sudo wg show`, and /var/log/wireguard.log.

let
  # ── Site settings ──────────────────────────────────────────────────
  # DynDNS name (or public IP) clients connect to. Set this in the o2 box.
  # Hostname clients connect to. o2 rotates the public IP on reconnect, so
  # this is a Njalla "Dynamic" record kept current by the updater daemon
  # below (the o2 box's own DynDNS client only speaks to paid/expiring
  # providers). Setup, once: in Njalla's DNS settings for munchy.gay add a
  # record of type "Dynamic" named "home"; Njalla shows a key for it. Store
  # that key root-only, outside git:
  #   sudo sh -c 'umask 077; echo KEY > /etc/njalla-ddns.key'
  endpoint = "home.munchy.gay";
  listenPort = 51820;
  # Interface that carries the LAN/internet uplink — pf NATs VPN traffic out
  # of it. The Mac is currently on Wi-Fi (en1); the Ethernet port is en0.
  # Wired is more reliable for a server: if you plug it in, change this.
  lanInterface = "en1";
  vpnNet = "10.8.0.0/24";
  serverAddr = "10.8.0.1/24";
  lanNet = "192.168.1.0/24";
  # DNS handed to clients: the o2 box, so o2.box and LAN names resolve.
  clientDns = "192.168.1.1";

  # ── Peers ──────────────────────────────────────────────────────────
  # One entry per device, produced by `sudo wg-add-client <name>...`.
  # guestNN entries are a pre-generated pool: hand out
  # /etc/wireguard/clients/guestNN.{conf,png} and record who got it in
  # `note`, so the next unused one is easy to find. Delete the line to revoke.
  peers = [
    # { name = "phone";  publicKey = "..."; ip = "10.8.0.3"; }
    { name = "laptop"; publicKey = "qwtpyijimpj8uQ0sRW3MNzNmyJtjuJKXg4DtCWpHMCI="; ip = "10.8.0.2"; note = "lucy laptop"; }
    { name = "guest01"; publicKey = "RTYdmdJFYairZgW6RnmtOFglA9/Mt8alMVk6V0ZCADw="; ip = "10.8.0.3"; note = "lukas phone"; }
    { name = "guest02"; publicKey = "8w8pZtVjpBreasrFNSrhYWplaFDOsOrLXWQCtEtGqAo="; ip = "10.8.0.4"; note = "unassigned"; }
    { name = "guest03"; publicKey = "XSshvj7BMKiQ2+d3/DMSopfEns/NtXKVeitRADhOB2g="; ip = "10.8.0.5"; note = "unassigned"; }
    { name = "guest04"; publicKey = "6x+sIEFC0ou0X9We6wdDX1DzecbMCf5nL44H99j4YQ0="; ip = "10.8.0.6"; note = "unassigned"; }
    { name = "guest05"; publicKey = "3Toc/qDSms7L5xvqlCzIFMJRyc02UAnBapXwN8HOMxQ="; ip = "10.8.0.7"; note = "unassigned"; }
    { name = "guest06"; publicKey = "ZPqZz0HCUNzf+pw7SWGIqriGXwDdzKK5TvclJ7yWQBM="; ip = "10.8.0.8"; note = "unassigned"; }
    { name = "guest07"; publicKey = "lz5F6ayX4M61qRq4auIdrwALO/S669bEsHMLt9bl/CM="; ip = "10.8.0.9"; note = "unassigned"; }
    { name = "guest08"; publicKey = "IOSKFxhy7ex7NcEtJlSzjpI3UvvjVmGMtkxJVj2p50s="; ip = "10.8.0.10"; note = "unassigned"; }
    { name = "guest09"; publicKey = "2NhyKUUvnQ6vCiBS64DEe8zQ1BjOgZTDjv8xPseR7k4="; ip = "10.8.0.11"; note = "unassigned"; }
    { name = "guest10"; publicKey = "TmlRC0mNaH95KeeXQiCp7HVm+EErkTF9gB8li1sp4Aw="; ip = "10.8.0.12"; note = "unassigned"; }
  ];

  keyDir = "/etc/wireguard";
  # Public index of generated clients, written by wg-add-client.
  clientIndex = "/etc/wireguard-clients.pub";
  peerBlock = p: ''
    # ${p.name}
    [Peer]
    PublicKey = ${p.publicKey}
    AllowedIPs = ${p.ip}/32
  '';

  wgConf = pkgs.writeText "wg0.conf" ''
    [Interface]
    Address = ${serverAddr}
    ListenPort = ${toString listenPort}
    # The private key is loaded from a root-only file rather than written
    # here, because this file lives in the world-readable Nix store.
    PostUp = wg set %i private-key ${keyDir}/server.key
    PostUp = sysctl -w net.inet.ip.forwarding=1
    PostUp = pfctl -a com.apple/wireguard -f /etc/pf.anchors/wireguard
    PostUp = pfctl -E
    PostDown = pfctl -a com.apple/wireguard -F all
    PostDown = sysctl -w net.inet.ip.forwarding=0

    ${lib.concatMapStringsSep "\n" peerBlock peers}
  '';

  # wg-quick on macOS forks wireguard-go and returns, so a bare "wg-quick up"
  # would look like a crashed daemon to launchd. Bring the tunnel up, then
  # stay alive while it exists; exit when it vanishes so KeepAlive restarts it.
  runScript = pkgs.writeShellScript "wireguard-run" ''
    set -u
    wg-quick down wg0 2>/dev/null || true
    wg-quick up wg0 || exit 1
    # wg-quick records which utunN it created; watch that interface.
    iface=$(cat /var/run/wireguard/wg0.name 2>/dev/null) || { echo "no wg0.name"; exit 1; }
    echo "[+] watching $iface"
    while ifconfig "$iface" >/dev/null 2>&1; do
      sleep 10
    done
    echo "[-] $iface gone, exiting so launchd restarts us"
    exit 1
  '';

  addClient = pkgs.writeShellScriptBin "wg-add-client" ''
    set -euo pipefail
    # sudo resets PATH, so reference the tools by store path.
    export PATH=${lib.makeBinPath [ pkgs.wireguard-tools pkgs.qrencode pkgs.coreutils pkgs.gnugrep ]}:$PATH
    if [ "$(id -u)" -ne 0 ]; then echo "run with sudo" >&2; exit 1; fi
    if [ $# -eq 0 ]; then echo "usage: sudo wg-add-client <name> [<name>...]   e.g. guest{01..10}" >&2; exit 1; fi
    dir=${keyDir}/clients
    index=${clientIndex}
    mkdir -p "$dir"; chmod 700 "$dir"
    touch "$index"; chmod 644 "$index"
    for name in "$@"; do
      if [ -e "$dir/$name.key" ]; then
        echo "client '$name' already exists — see $dir/$name.conf" >&2; continue
      fi
      # next free host address: 10.8.0.2 upwards, skipping ones already handed out
      used=$(cat "$dir"/*.ip 2>/dev/null || true)
      n=2
      while echo "$used" | grep -qx "10.8.0.$n"; do n=$((n+1)); done
      ip="10.8.0.$n"
      key=$(umask 077; wg genkey)
      pub=$(echo "$key" | wg pubkey)
      (umask 077; echo "$key" > "$dir/$name.key"; echo "$ip" > "$dir/$name.ip")
      (umask 077; cat > "$dir/$name.conf" <<CONF
    [Interface]
    PrivateKey = $key
    Address = $ip/32
    DNS = ${clientDns}

    [Peer]
    PublicKey = $(cat ${keyDir}/server.pub)
    Endpoint = ${endpoint}:${toString listenPort}
    # Full tunnel. For LAN-only access use: AllowedIPs = ${vpnNet}, ${lanNet}
    AllowedIPs = 0.0.0.0/0
    PersistentKeepalive = 25
    CONF
      )
      qrencode -t ansiutf8 < "$dir/$name.conf" > "$dir/$name.qr"
      qrencode -t png -o "$dir/$name.png" < "$dir/$name.conf"
      # Public index (name, public key, IP) — nothing secret, readable by all.
      echo "$name $pub $ip" >> "$index"
      echo "created $name -> $ip"
    done
    echo
    echo "peers entries for machines/mac/wireguard.nix (then: update):"
    awk '{ printf "    { name = \"%s\"; publicKey = \"%s\"; ip = \"%s\"; }\n", $1, $2, $3 }' "$index"
    echo
    echo "hand-out files per client in $dir: <name>.conf (text), <name>.png (QR), <name>.qr (terminal QR)"
  '';
in
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
    wireguard-go
    qrencode
    addClient
  ];

  environment.etc."wireguard/wg0.conf".source = wgConf;

  # NAT VPN clients out of the uplink. The stock macOS pf ruleset has no
  # block-all, so forwarded traffic needs no explicit pass rules.
  environment.etc."pf.anchors/wireguard".text = ''
    nat on ${lanInterface} from ${vpnNet} to any -> (${lanInterface})
  '';

  # Server key: generated once, root-only, never in the store.
  system.activationScripts.postActivation.text = ''
    mkdir -p ${keyDir}; chmod 700 ${keyDir}
    if [ ! -s ${keyDir}/server.key ]; then
      echo "wireguard: generating server key"
      (umask 077; ${pkgs.wireguard-tools}/bin/wg genkey > ${keyDir}/server.key)
    fi
    ${pkgs.wireguard-tools}/bin/wg pubkey < ${keyDir}/server.key > ${keyDir}/server.pub
    chmod 644 ${keyDir}/server.pub
    # Pick up config changes on switch (wg-quick re-reads wg0.conf on restart).
    launchctl kickstart -k system/org.nixos.wireguard 2>/dev/null || true
  '';

  # DynDNS updater: every 5 minutes, point the Njalla record at our current
  # public IPv4. "auto" makes Njalla use the request's source address, and
  # curl -4 guarantees that is the IPv4 one. Does nothing until the key
  # file exists. Log: /var/log/njalla-ddns.log
  launchd.daemons.njalla-ddns = {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.writeShellScript "njalla-ddns-update" ''
        set -u
        [ -s /etc/njalla-ddns.key ] || exit 0
        ${pkgs.curl}/bin/curl -4 -sS -m 20 \
          "https://njal.la/update/?h=${endpoint}&k=$(cat /etc/njalla-ddns.key)&auto" \
          || echo "njalla update failed"
        echo
      ''}" ];
      RunAtLoad = true;
      StartInterval = 300;
      StandardOutPath = "/var/log/njalla-ddns.log";
      StandardErrorPath = "/var/log/njalla-ddns.log";
    };
  };

  launchd.daemons.wireguard = {
    serviceConfig = {
      ProgramArguments = [ "${runScript}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/var/log/wireguard.log";
      StandardErrorPath = "/var/log/wireguard.log";
      EnvironmentVariables.PATH = lib.makeBinPath [
        pkgs.wireguard-tools
        pkgs.wireguard-go
        pkgs.bash
        pkgs.coreutils
      ] + ":/usr/bin:/bin:/usr/sbin:/sbin";
    };
  };
}
