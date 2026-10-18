#!/bin/sh

BOOTSTRAP_URL="https://thespinmaster.github.io/venus-os-addons/feeds"
BOOTSTRAP_RELEASE="release"
BASE_SOURCE_FILE=
log_prefix=

log() { echo "${log_prefix}$*"; }

for file in /media/*/venus-data-vespera-blind-install.tgz; do
	[ -f "$file" ] && BASE_SOURCE_FILE="${file%.tgz}"
done

[ "${1:-}" = "--dry-run" ] && dry_run=1 || dry_run=0
[ "$dry_run" -eq 0 ] && log_prefix="blind-install:"

[ -n "${BASE_SOURCE_FILE}" ] && [ -f "${BASE_SOURCE_FILE}.source" ] &&
	IFS=' ' read -r BOOTSTRAP_URL BOOTSTRAP_RELEASE < "${BASE_SOURCE_FILE}.source"

log "running vespera bind install"

log "waiting for dbus settings"
while ! dbus -y | grep -q "com.victronenergy.settings"; do
  log "waiting for dbus settings"
	sleep 1
done

log "${log_prefix}installing - vespera from:$BOOTSTRAP_URL/$BOOTSTRAP_RELEASE"

if ! wget -qO /tmp/vespera-bootstrap "$BOOTSTRAP_URL/vespera-bootstrap"; then
	log "${log_prefix}failed to download vespera-bootstrap, exiting"
	exit 1
else
	echo "executing vespera-bootstrap"
	if [ "$dry_run" -eq 0 ]; then
		if ! sh /tmp/vespera-bootstrap --no-prompt --feed "$BOOTSTRAP_URL/$BOOTSTRAP_RELEASE"; then
			log "${log_prefix}vespera-bootstrap failed, exiting"
			exit 1
		fi
	fi
fi

log "vespera version: $(vespera version)"
if [ -n "${BASE_SOURCE_FILE}" ] && [ -f "${BASE_SOURCE_FILE}.sh" ]; then
	log "${log_prefix}calling post script:${BASE_SOURCE_FILE}.sh"
	[ "$dry_run" -eq 0 ] &&
		"${BASE_SOURCE_FILE}.sh"
fi

[ "$dry_run" -eq 0 ] && rm -f "${0}"
