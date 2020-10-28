#!/bin/bash -ue

. u.sh

h="$([[ "${1:-}" != "" ]] && echo "$1" || date +%H)"
h="$(sed 's/^0//' <<<$h)"
echo "$(date): hour=$h"

PIHOLE_RESTART_NEEDED=false
kidsOn="$(head -$((h+1)) kids.conf |tail -1| sed 's/^[0-9]* *//')"
if [[ "$kidsOn" ]]; then
	kidsAllow
else
	kidsBlock
fi
updateEtcHosts
restartDnsIfNeeded
