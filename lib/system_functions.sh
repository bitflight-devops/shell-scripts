#!/usr/bin/env bash
get_iso_time() {
	date +%Y-%m-%dT%H:%M:%S%z
}

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

is_darwin() {
	case "$(uname -s)" in
	*darwin*) true ;;
	*Darwin*) true ;;
	*) false ;;
	esac
}

is_wsl() {
	case "$(uname -r)" in
	*microsoft*) true ;; # WSL 2
	*Microsoft*) true ;; # WSL 1
	*) false ;;
	esac
}

get_distribution() {
	local lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [[ -r /etc/os-release ]]; then
		lsb_dist="$(. /etc/os-release && echo "${ID}")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "${lsb_dist}"
}

process_is_running() {
	PID="$1"
	if [[ -n ${PID} ]]; then
		kill -0 "${PID}" >/dev/null 2>&1
		return $?
	fi
	printf "%s(): No PID provided" "${0}"
	return 1
}

export SYSTEM_FUNCTIONS_LOADED=1
