#!/bin/sh

this_path="$(dirname "${0}")"
log_prefix=""
dry_run=0

log() { echo "${log_prefix}$*"; }

if [ "${1:-}" = "--dry-run" ]; then
	dry_run=1
else
	log_file=/var/log/vespera/blind-install.log
	log_prefix="vespera:blind-install:pre-hook:"
	mkdir -p "${log_file%/*}"
	exec > "$log_file" 2>&1
fi

log "blind install"

install=0
[ -f "$this_path/blind-install.force" ] && install=1
[ $install -eq 0 ] && ! command -v vespera >/dev/null 2>&1 && install=1
if [ $install -eq 0 ] && [ -f "$this_path/blind-install-vespera.version" ]; then
	version_to_install="$(cat "$this_path/blind-install-vespera.version")"
	if [ -n "$version_to_install" ]; then
		log "installed_version:$installed_version"
		log "version_to_install:$version_to_install"
		installed_version="$(awk '/Version:/ {print $2}' "/data/var/vespera/info/vespera.control" 2>/dev/null)"
		# shellcheck disable=SC1091
		. "/data/apps/available/vespera/libs/version-lib"
		version_lib_check "<$version_to_install" "$installed_version" && install=1
	fi
fi

log "install:$install"

if [ $install -eq 1 ]; then
	install_script="$this_path/blind-install.sh"

	if [ -f "$install_script" ]; then
		log "calling blind-install script"

		if [ "$dry_run" -eq 0 ]; then

			tmp_script=$(mktemp /tmp/blind-install.XXXXXX) || exit 1
			cp "$install_script" "$tmp_script" || exit 1
			nohup sh -c "$tmp_script 2>&1 | tai64n >> $log_file" </dev/null >/dev/null 2>&1 &
		fi
		exit 0
	fi
	log "blind-install script file not found"
	exit 1
else
  log "vespera already installed, exiting"
	exit 1
fi
