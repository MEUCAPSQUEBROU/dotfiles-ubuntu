#!/bin/bash
# Ethernet speed as Pango markup for the "Rede" desktop widget.
# Each run compares byte counters with the previous run to get the rate.
# Interface: $NET_IFACE, ou a da rota padrão, ou a primeira placa que não seja loopback
IFACE=${NET_IFACE:-$(ip route show default 2>/dev/null | awk '{print $5; exit}')}
[[ -n $IFACE ]] || IFACE=$(ls /sys/class/net | grep -vx lo | head -1)
WIDTH=30   # history points; 30 blocks at 9pt match the Disco bar width
STATE="${XDG_RUNTIME_DIR:-/tmp}/net-widget/$IFACE"
mkdir -p "${STATE%/*}"

rx=$(<"/sys/class/net/$IFACE/statistics/rx_bytes")
tx=$(<"/sys/class/net/$IFACE/statistics/tx_bytes")
now=$(date +%s%N)
link=$(cat "/sys/class/net/$IFACE/speed" 2>/dev/null)
oper=$(<"/sys/class/net/$IFACE/operstate")

prev=""
[[ -r $STATE ]] && prev=$(<"$STATE")

awk -v rx="$rx" -v tx="$tx" -v now="$now" -v prev="$prev" -v width="$WIDTH" \
    -v link="$link" -v oper="$oper" -v state="$STATE" '
function fmt(bps,   v) {   # bits per second -> "12,4 Mbps"
    if (bps >= 1e9)      { v = sprintf("%.1f", bps / 1e9); u = "Gbps" }
    else if (bps >= 1e6) { v = sprintf(bps >= 1e8 ? "%.0f" : "%.1f", bps / 1e6); u = "Mbps" }
    else                 { v = sprintf("%.0f", bps / 1e3); u = "kbps" }
    sub(/\./, ",", v)
    return v
}
BEGIN {
    n = split(prev, p, " ")
    down = 0; up = 0
    if (n >= 3 && now > p[1]) {
        dt = (now - p[1]) / 1e9
        if (rx >= p[2]) down = (rx - p[2]) * 8 / dt
        if (tx >= p[3]) up   = (tx - p[3]) * 8 / dt
    }
    # history of download rates, oldest first
    k = 0
    for (i = 4; i <= n; i++) h[++k] = p[i]
    h[++k] = down
    start = (k > width) ? k - width + 1 : 1

    line = now " " rx " " tx
    for (i = start; i <= k; i++) line = line " " int(h[i])
    print line > (state ".tmp"); close(state ".tmp")
    system("mv -f \"" state ".tmp\" \"" state "\"")

    peak = 1e6   # scale floor: 1 Mbps, so idle traffic stays flat
    for (i = start; i <= k; i++) if (h[i] > peak) peak = h[i]
    split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", b, " ")
    spark = ""
    for (i = k - start + 1; i < width; i++) spark = spark b[1]   # pad until history fills
    for (i = start; i <= k; i++) {
        lvl = int(h[i] / peak * 7 + 0.5) + 1
        spark = spark b[lvl > 8 ? 8 : lvl]
    }

    dv = fmt(down); du = u
    uv = fmt(up);   uu = u
    if (oper != "up") foot = "Ethernet · desconectado"
    else foot = "Ethernet · " (link >= 1000 ? link / 1000 " Gbps" : link " Mbps")

    print "<span size=\"12pt\" alpha=\"75%\">Rede</span>"
    print "<span size=\"30pt\" weight=\"light\">↓ " dv "</span> <span size=\"10pt\" alpha=\"75%\">" du "</span>"
    print "<span size=\"16pt\" weight=\"light\">↑ " uv "</span> <span size=\"10pt\" alpha=\"75%\">" uu "</span>"
    print "<span size=\"9pt\" foreground=\"#7CE38B\">" spark "</span>"
    print "<span size=\"10pt\" alpha=\"75%\">" foot "</span>"
}'
