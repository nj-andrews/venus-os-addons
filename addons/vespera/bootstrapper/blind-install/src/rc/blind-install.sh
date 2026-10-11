#!/bin/bash

declare log_path=/var/log/vespera/
declare log=$log_path/blind-install.log

declare URI=http://192.168.10.32:8808
declare RELEASE="develop"
# declare URI=https://thespinmaster.github.io/venus-os-addons/feeds

mkdir -p "$log_path"
exec > "$log" 2>&1

echo "Running vespera bind install"
echo "Installing - vespera from:$URI/$RELEASE"

wget -qO /tmp/vespera-bootstrap "$URI/vespera-bootstrap" \
	&& sh /tmp/vespera-bootstrap "$URI/$RELEASE/vespera" \
		|| { echo "bootstrap failed, exiting"; exit 1; };

declare install_conf
install_conf=$(find /run/media -mindepth 2 -maxdepth 2 -type f \
	-name 'venus-data-vespera-blind-install.conf' -print -quit)

if [[ -f "$install_conf" ]]; then
	declare -a package_commands=()

	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]]; then
			continue
		fi

		read -r -a tokens <<< "$line"

		case "${tokens[0]}" in
			package)
				if [[ ${#tokens[@]} -lt 3 ]]; then
					echo "Invalid package command: $line"
					exit 1
				fi
				package_commands+=("$line")
				;;
			*)
				echo "Unsupported command: $line"
				exit 1
				;;
		esac
	done < "$install_conf"

	for command in "${package_commands[@]}"; do
		read -r -a package_tokens <<< "$command"

		declare package_action="${package_tokens[1]}"
		declare package_name="${package_tokens[$((${#package_tokens[@]} - 1))]}"
		declare -a package_args=()

		if [[ ${#package_tokens[@]} -gt 3 ]]; then
			package_args=("${package_tokens[@]:2:$((${#package_tokens[@]} - 3))}")
		fi

		vespera "$package_action" "${package_args[@]}" "$package_name"
	done
fi

rm -f "${BASH_SOURCE[0]}"
echo "Done"