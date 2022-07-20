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

[[ -z ${SYSTEM_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"

#########################
# FILE REMOTE UTILITIES #
#########################
# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
# Successive backoffs double the timeout.
withBackoff() {
	local max_attempts=${ATTEMPTS:-5}
	local timeout=${TIMEOUT:-1}
	local attempt=1
	local exitCode=0

	while ((attempt < max_attempts)); do
		if "$@"; then
			return 0
		else
			exitCode=$?
		fi

		warning "Failure! Retrying in ${timeout}.."
		sleep "${timeout}"
		attempt=$((attempt + 1))
		timeout=$((timeout * 2))
	done

	if [[ ${exitCode} -gt 0 ]]; then
		error "${0}(): All Attempts Failed! ($*)"
	fi

	return "${exitCode}"
}

checkExistURL() {
	local -r url="${1}"
	if grep -q 'X-Amz-Credential' <<<"${url}"; then
		warning "Skipping checkExistURL for ${url}, it is a presigned URL"
		return 0
	fi
	if [[ "$(existURL "${url}")" == 'false' ]]; then
		fatal "${0}(): url '${url}' not found"
	fi
}

##
## CURL_DISABLE_ETAG_DOWNLOAD=true to disable etag download and comparison
downloadFile() {
	set -e
	local -r url="${1}"
	local -r destinationFile="${2:--}"
	local overwrite="${3:-true}"

	checkExistURL "${url}"

	# Check Overwrite
	isBoolean "${overwrite}" || fatal "${0}(): 'overwrite' must be a boolean"

	# Validate
	if [[ ${destinationFile} != "-" ]]; then
		if [[ -f ${destinationFile} ]]; then
			if isFalse "${overwrite}"; then
				fatal "${0}(): file '${destinationFile}' found"
			fi
			rm -f "${destinationFile}"
		elif [[ -e ${destinationFile} ]]; then
			fatal "${0}(): file '${destinationFile}' already exists"
		fi

		# Download
		dirPath="$(dirname "${destinationFile}")"
		fileName="$(basename "${destinationFile}")"
		debug "\nDownloading '${url}' to '${destinationFile}'\n"
	else
		local TO_STD_OUT=true
	fi
	if command_exists wget; then
		DOWNLOAD_ARGS=(--timestamping -q --no-dns-cache --no-hsts)
		DOWNLOAD_ARGS+=(--no-http-keep-alive --compression=auto --continue)
		DOWNLOAD_ARGS+=(--dns-timeout=3 --waitretry=2 --tries=2)
		DOWNLOAD_ARGS+=(--read-timeout=-1 --connect-timeout=30 --xattr)
		if [[ -z ${TO_STD_OUT} ]] && [[ ${overwrite} == 'false' ]]; then
			DOWNLOAD_ARGS+=(--no-clobber)
		fi
		withBackoff wget -q -O "${destinationFile}" "${url}" "${DOWNLOAD_ARGS[@]}"
	elif command_exists curl || installCURLCommand >/dev/null 2>&1; then
		DOWNLOAD_ARGS=(--create-dirs)
		DOWNLOAD_ARGS+=(--fail --remote-time --compressed)
		if [[ -z ${TO_STD_OUT} ]] && [[ -f ${destinationFile} ]]; then
			lastDownloadedModifiedDate=$(stat -c '%y' "${destinationFile}")
			lastModifiedDate=$(TZ=GMT date -d "${lastDownloadedModifiedDate}" '+%a, %d %b %Y %T %Z')
			DOWNLOAD_ARGS+=(--header="If-Modified-Since: ${lastModifiedDate}")
			if isFalse "${CURL_DISABLE_ETAG_DOWNLOAD}"; then
				etagPath="/usr/local/etc/etags/${dirPath}/"
				mkdir -p "${etagPath}"
				etagFile="${etagPath}/.etag.${fileName//[^a-zA-Z0-9]/_}"
				DOWNLOAD_ARGS+=(--etag-save="${etagFile}" --etag-compare="${etagFile}")
			fi
		fi
		withBackoff curl -sSL -o "${destinationFile}" "${url}" "${DOWNLOAD_ARGS[@]//=/ }"
	else
		fatal "${0}(): wget or curl not found"
	fi
}

installCURLCommand() {
	APPS_TO_INSTALL=()
	if apt-cache policy ca-certificates | grep -q -v 'Unable to locate package'; then
		APPS_TO_INSTALL+=("ca-certificates")
	fi
	if ! command_exists curl; then
		APPS_TO_INSTALL+=("curl")
	fi
	if [[ ${#APPS_TO_INSTALL[@]} -gt 0 ]]; then
		install_app "${#APPS_TO_INSTALL[@]}"
	fi
}

existURL() {
	local -r url="${1}"
	# Install Curl
	installCURLCommand >'/dev/null'
	# Check URL
	if (curl -f --head -L "${url}" -o '/dev/null' -s ||
		curl -f -L "${url}" -o '/dev/null' -r 0-0 -s); then
		echo 'true' && return 0
	fi
	echo 'false' && return 1
}

getRemoteFileContent() {
	local -r url="${1}"
	checkExistURL "${url}"
	curl -s -X 'GET' -L "${url}"
}

export REMOTE_UTILITY_FUNCTIONS_LOADED=1
