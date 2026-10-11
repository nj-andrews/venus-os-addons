#!/bin/bash

declare log_path=/var/log/vespera/
declare log=$log_path/blind-install.log

if [[ ! -d "$log_path" ]]; then
	mkdir -p "$log_path"
fi

exec > "$log" 2>&1

echo "starting blind install"
"$(date)"

this_path="$(dirname "${BASH_SOURCE[0]}")"

install_script="$this_path/blind-install.sh"
if [[ -f "$install_script" ]]; then
  cp "$install_script" /tmp/
	echo "calling blind-install script"
  nohup /tmp/blind-install.sh "=${1:-}"> /dev/null &
else
  echo "blind-install script file not found"
fi
