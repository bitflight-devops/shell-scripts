#!/usr/bin/env bash

# Download the latest version of the script from the following URL:
# https://raw.githubusercontent.com/bitflight-devops/scripts/master/install.sh

set -eu
printf '\n'

BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

SHELL_SCRIPTS_GITHUB_REPOSITORY="bitflight-devops/shell-scripts"
DEFAULT_INSTALL_DIR="${HOME}/.bin/${SHELL_SCRIPTS_GITHUB_REPOSITORY}"

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

# Test if a location is writeable by trying to write to it. Windows does not let
# you test writeability other than by writing: https://stackoverflow.com/q/1999988
test_writeable() {
	path="${1:-}/test.txt"
	if touch "${path}" 2>/dev/null; then
		rm "${path}"
		return 0
	else
		return 1
	fi
}

get_last_github_author_email() {
	jq -r --arg default "$1" '.check_suite // .workflow_run // .sender // . | .head_commit // .commit.commit // . | .author.email // .pusher.email // .email // "$default"' "${GITHUB_EVENT_PATH}"
}
get_last_github_author_name() {
	jq -r '.pull_request // .check_suite // .workflow_run // .issue // .sender // .commit // .repository // . | .head_commit // .commit // . | .author.name // .pusher.name // .login // .user.login // .owner.login // ""' "${GITHUB_EVENT_PATH}"
}

configure_git() {
	# This installer is often run during github actions, so we need to make sure
	# that the git user is set.
	if command_exists git; then
		# If we get the name and it succeeds
		if git config --global user.name >/dev/null 2>&1; then
			# And that name is not empty
			if [[ -z "$(git config --global user.name)" ]]; then
				git config --global user.name "$(get_last_github_author_name)"
			fi
		else
			git config --global user.email "$(get_last_github_author_name)"
		fi
		local -r user="$(git config --global user.name)"
		if git config --global user.email >/dev/null 2>&1; then
			if [[ -z "$(git config --global user.email)" ]]; then
				git config --global user.email "$(get_last_github_author_email ${user})"
			fi
		else
			git config --global user.email "$(get_last_github_author_email ${user})"
		fi
	fi

}

download_shell_scripts() {
	local releases_url="https://api.github.com/repos/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/releases/latest"

	if command_exists git; then
		configure_git
		local need_to_clone=true
		if [[ -d ${DEFAULT_INSTALL_DIR} ]]; then
			if [[ $(git -C "${DEFAULT_INSTALL_DIR}" remote -v) =~ (${SHELL_SCRIPTS_GITHUB_REPOSITORY}) ]]; then
				need_to_clone=false
				notice "Updating shell-scripts..."
				git -C "${DEFAULT_INSTALL_DIR}" stash
				git -C "${DEFAULT_INSTALL_DIR}" reset --hard HEAD
				git -C "${DEFAULT_INSTALL_DIR}" pull -f
				git -C "${DEFAULT_INSTALL_DIR}" stash pop
			else
				mv "${DEFAULT_INSTALL_DIR}" "${DEFAULT_INSTALL_DIR}-old"
			fi
		fi

		if [[ ${need_to_clone} == true ]]; then
			git clone "https://github.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}.git" "${DEFAULT_INSTALL_DIR}"
		fi

	fi
}
download() {
	file="$1"
	url="$2"
	if command_exists curl; then
		curl --fail --silent --location --output $file $url
	elif command_exists wget; then
		wget --quiet --output-document=$file $url
	elif command_exists fetch; then
		fetch --quiet --output=$file $url
	else
		error "No HTTP download program (curl, wget, fetch) found, exiting…"
		return 1
	fi
}
