#!/bin/bash
# Disk usage of / as Pango markup for the "Disco" desktop widget.
read -r size used pcent < <(df -B1 --output=size,used,pcent / | tail -1)
pct=${pcent%\%}

gb() { awk -v b="$1" 'BEGIN { printf "%.0f GB", b / 1e9 }'; }

# Bar color goes from green to amber to red as the disk fills
if   (( pct >= 90 )); then color='#FF6B6B'
elif (( pct >= 75 )); then color='#FFC857'
else                       color='#7CE38B'
fi

width=30
filled=$(( (pct * width + 50) / 100 ))
(( pct > 0 && filled == 0 )) && filled=1
bar_on=$(printf '━%.0s' $(seq 1 $filled))
bar_off=$( (( filled < width )) && printf '━%.0s' $(seq 1 $(( width - filled ))) )

echo "<span size='12pt' alpha='75%'>Disco</span>"
echo "<span size='30pt' weight='light'>${pct}%</span> <span size='10pt' alpha='75%'>usado</span>"
echo "<span size='11pt'><span foreground='${color}'>${bar_on}</span><span alpha='25%'>${bar_off}</span></span>"
echo "<span size='10pt' alpha='75%'>$(gb "$used") de $(gb "$size")</span>"
