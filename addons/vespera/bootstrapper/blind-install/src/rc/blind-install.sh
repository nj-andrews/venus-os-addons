#!/bin/sh

SCRIPT_DIR="$(dirname "$0")"
CONF_FILE="$1"
DRY_RUN=
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1 || DRY_RUN=0

BOOTSTRAP_SCRIPT=$SCRIPT_DIR/vespera-bootstrap
BOOTSTRAP_URL="https://nj-andrews.github.io/venus-os-addons/feeds"
BOOTSTRAP_RELEASE="release"

log() { echo "blind-install:$*"; }
exec_or_log() { [ "$DRY_RUN" -eq 1 ] && { echo "$@"; return; }; "$@"; }
read_config_value() {
	value=$(sed -n "s/^$2=//p" "$1")
	printf '%s\n' "${value:-${3-}}"
}

log "running vespera bind install"

# check the existance of /media/[sdcard]/vespera-latest.ipk
# or /media/[sdcard]/venus-data-vespera-blind-install.conf
# vespera-latest.ipk takes preference.
if [ -n "${CONF_FILE}" ]; then
	path_of_src="${CONF_FILE%/*}"
	if [ -f "${path_of_src}/vespera-latest.ipk" ]; then
		VESPERA_URL="${path_of_src}"
	else
		if [ -f "${CONF_FILE}" ]; then
			BOOTSTRAP_URL=$(read_config_value "${CONF_FILE}" "bootstrap-url" "$BOOTSTRAP_URL")
			BOOTSTRAP_RELEASE=$(read_config_value "${CONF_FILE}" "bootstrap-release" "$BOOTSTRAP_RELEASE")
		fi
	fi
fi

while ! dbus -y | grep -q "com.victronenergy.settings"; do
	log "waiting for dbus settings"
	sleep 1
done

# check if BOOTSTRAP_URL is empty or starts with "/" (meaning use sdcard)
if [ -z "$VESPERA_URL" ]; then
	log "downloading - bootstrap file :$BOOTSTRAP_URL/vespera-bootstrap"
	if ! wget -qO "$BOOTSTRAP_SCRIPT" "$BOOTSTRAP_URL/vespera-bootstrap"; then
		log "failed to download vespera-bootstrap, exiting"
		exit 1
	fi
	VESPERA_URL="${BOOTSTRAP_URL}/$BOOTSTRAP_RELEASE"
fi

echo "executing vespera-bootstrap: $VESPERA_URL"
if ! exec_or_log sh "$BOOTSTRAP_SCRIPT" --no-prompt --feed "$VESPERA_URL" ; then
	log "vespera-bootstrap failed, exiting"
	exit 1
fi

log "vespera version: $(vespera version)"
POST_SCRIPT_FILE="${CONF_FILE%.*}.sh"
if [ -f "${POST_SCRIPT_FILE}.sh" ]; then
	log "calling post script:${POST_SCRIPT_FILE}"
	exec_or_log "${POST_SCRIPT_FILE}"
fi

[ "$DRY_RUN" -eq 0 ] && rm -rf "${SCRIPT_DIR}"
