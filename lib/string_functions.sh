#!/usr/bin/env bash
# Current Script Directory
if [[ -z ${SCRIPTS_LIB_DIR} ]]; then
	if grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; then
		# shellcheck disable=SC2296
		SCRIPTS_LIB_DIR="${0:a:h}"
		SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
	else
		SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
	fi
fi

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

iscolorcode() {
	grep -E $'\e\\[''(?:[0-9]{1,3})(?:(?:;[0-9]{1,3})*)?[mGK]' <<<"$1"
}

colorcode() {
	local -r color="${1}"
	if iscolorcode "${color}"; then
		printf '%s' "${color}"
	else
		local -r color_var_name="$(uppercase "${color}")"
		local -r colorcode="${!color_var_name}"
		if iscolorcode "${colorcode}"; then
			printf '%s' "${colorcode}"
		else
			printf '%s' "${color}"
		fi
	fi
}

stripcolor() {
	# shellcheck disable=SC2001
	sed -e 's/([[:cntrl:]]\[[[:digit:]]{1,3}(\;[[:digit:]]{1,3})*[mGK])[[:space:]]*//g' <<<"${*}"
}

if [[ -f "${SCRIPTS_LIB_DIR}/trim_keeping_colors.perl" ]] && command_exists perl; then
	trim() {
		"${SCRIPTS_LIB_DIR}/trim_keeping_colors.perl" <<<"${*}"
	}
else
	trim() {
		sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"${*}"
	}
fi
# Alias for trim
trimString() {
	trim "${*}"
}

# Is provided string empty
empty() {
	if [[ -z "$(tr -d '[:space:]' <<<"${*}")" ]]; then
		echo 'true' && return 0
	else
		echo 'false' && return 1
	fi
}

# Alias for empty
isEmptyString() {
	empty "${*}"
}

trim_dash() {
	sed 's/^[- ]*//g;s/[- ]*$//g' <<<"${*}"
}

uppercase() {
	tr '[:lower:]' '[:upper:]' <<<"${*}"
}

lowercase() {
	tr '[:upper:]' '[:lower:]' <<<"${*}"
}

squash_spaces() {
	tr -s '[:space:]' ' ' <<<"${*}"
}

# Remove Starting # from the string
# Trim leading and trailing spaces
# Uppercase the first letter of each word in the string
# Remove duplicated whitespace
# Set the Jira Ticket Keys to Uppercase
# Do not modify words that start with non-alphanumeric characters
titlecase() {
	local string="$(trim "${*###}")"

	perl -pe 's/^#+//g;s/(^\h*|\h*$)//g;s/(\w)([\w'"'"']*)/\U$1\L$2/gm;tr/ //s;s/([a-zA-Z]{3,8}-[0-9]+)/\U$1/g;' <<<"${string}"
}

export STRING_FUNCTIONS_LOADED=1
