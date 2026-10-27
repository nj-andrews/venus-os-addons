#!/bin/sh

this_path="$(dirname "${0}")"
log_prefix=""
dry_run=0
conf_file=

log() { echo "${log_prefix}$*"; }
exec_or_log() { [ "$dry_run" -eq 1 ] && { echo "$@"; return; }; "$@"; }
read_config_value() {
	value=$(sed -n "s/^$2=//p" "$1")
	printf '%s\n' "${value:-${3-}}"
}

# find the location of venus-data-vespera-blind-install.tgz (and strip .tgz)
for file in /media/*/venus-data-vespera-blind-install.tgz /media/*/venus-data-vespera-blind-install.zip; do
	if [ -f "$file" ]; then
		conf_file="${file%.*}.conf"
		break
	fi
done

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
installed_version="$(awk '/Version:/ {print $2}' "/data/var/vespera/info/vespera.control" 2>/dev/null)"
if [ -n "$installed_version" ]; then
	# vespera is installed
	#if conf file exists; then
	log "installed version:$installed_version"
	if [ -f "${conf_file}" ]; then
		min_version=$(read_config_value "${conf_file}" "min-version" "1.0")
		if [ -n "$min_version" ]; then
			log "min version:$min_version"
			# shellcheck disable=SC1091
			. "/data/apps/available/vespera/libs/version-lib"
			version_lib_check "<$min_version" "$installed_version" && install=1
		fi
	fi
else
	install=1
fi

log "install:$install"

if [ "$install" -eq 1 ]; then

	if [ -f "$this_path/blind-install.sh" ]; then
		log "calling blind-install script"

		tmp_script=$(mktemp -d /tmp/blind-install.XXXXXX) || exit 1

		exec_or_log cp "$this_path/blind-install.sh" "$tmp_script" || exit 1
		exec_or_log cp "$this_path/vespera-bootstrap" "$tmp_script" || exit 1
		exec_or_log nohup sh -c "$tmp_script/blind-install.sh ${conf_file} ${1:-} 2>&1 | tai64n >> $log_file" </dev/null >/dev/null 2>&1 &

	else
		log "blind-install script file not found"
	fi
else
  log "vespera already installed, exiting"
fi
