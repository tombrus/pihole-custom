#!/bin/bash
#################################################################
youtube_block=(
	www.youtube-nocookie.com
	i1.ytimg.com
	clients6.google.com
	s.youtube.com
	youtubei.googleapis.com
	www.googleadservices.com
)
youtube_wild=(
	googlevideo.com
	youtube.com
)
twitch_block=(
	api.mixpanel.com
	spade.twitch.com
	pubads.g.doubleclick.net
	sb.scorecardresearch.com
)
#################################################################
pihole() {
	/usr/local/bin/pihole "$@"
}
restartDnsIfNeeded() {
	if [[ $PIHOLE_RESTART_NEEDED == true ]]; then
		echo "...restart DNS"
		pihole restartdns
		PIHOLE_RESTART_NEEDED=false
	fi
}
piholeRestartMonitored() {
	local tmp=/tmp/moni$$
	pihole "$@" >$tmp
	PIHOLE_RESTART_NEEDED=$([[ $PIHOLE_RESTART_NEEDED == true || -s $tmp ]] && echo true || echo false)
	rm $tmp
}
block() {
	piholeRestartMonitored -b     -q    -nr "$@"
}
unblock() {
    piholeRestartMonitored -b     -q -d -nr "$@"
}
blockWild() {
	piholeRestartMonitored --wild -q    -nr "$@"
}
unblockWild() {
	piholeRestartMonitored --wild -q -d -nr "$@"
}
#################################################################
kidsBlock() {
	block       "${twitch_block[@]}"
	block       "${youtube_block[@]}"
	blockWild   "${youtube_wild[@]}"
	if [[ $PIHOLE_RESTART_NEEDED == true ]]; then
		echo "...blocked kids"
	fi
}
kidsAllow() {
	unblock     "${twitch_block[@]}"
	unblock     "${youtube_block[@]}"
	unblockWild "${youtube_wild[@]}"
	if [[ $PIHOLE_RESTART_NEEDED == true ]]; then
		echo "...unblocked kids"
	fi
}
kidsBlockManual() {
	PIHOLE_RESTART_NEEDED=false
	kidsBlock
	restartDnsIfNeeded
}
kidsAllowManual() {
	PIHOLE_RESTART_NEEDED=false
	kidsAllow
	restartDnsIfNeeded
}
#################################################################
LOCAL_DOMAIN="$(domainname)"
LOCAL_GATEWAY="$(ip route |fgrep default | sed 's/default via //;s/ .*//')"
updateEtcHosts() {
    if [[ "$LOCAL_GATEWAY" != "" && "$LOCAL_DOMAIN" != "" ]]; then
        if [[ ! -f /etc/hosts-backup ]]; then
            sudo cp /etc/hosts /etc/hosts-backup
        fi
        (	cat /etc/hosts-backup
            echo "####### generated:"
            for i in $(seq 1 254); do
                local ip="$(printf "%s.%d" "$(sed 's/[.][0-9][0-9]*$//' <<<$LOCAL_GATEWAY)" "$i")"
                local name="$(dig @$LOCAL_GATEWAY +short -x "$ip" |sed 's/\.$//;s/\.'"$LOCAL_DOMAIN"'$//')"
                if [[ $name ]]; then
                    printf "%-15s %s\n" "$ip" "$name"
                fi
            done
        ) > /tmp/hosts-$$
        if ! cmp -s /etc/hosts /tmp/hosts-$$; then
            echo "$(date): updated /etc/hosts: $(wc -l </etc/hosts) => $(wc -l </tmp/hosts-$$) lines"
            sudo cp /tmp/hosts-$$ /etc/hosts
            PIHOLE_RESTART_NEEDED=true
        fi
        rm /tmp/hosts-$$
    fi
}
