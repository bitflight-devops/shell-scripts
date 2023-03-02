#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z ${SCRIPTS_LIB_DIR:-}   ]]; then
  LC_ALL=C
  export LC_ALL
  set +e
  read -r -d '' GET_LIB_DIR_IN_ZSH <<- 'EOF'
	0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
	0="${${(M)0:#/*}:-$PWD/$0}"
	SCRIPTS_LIB_DIR="${0:a:h}"
	SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
	EOF
  set -e
  # by using a HEREDOC, we are disabling shellcheck and shfmt
  set +e
  read -r -d '' LOOKUP_SHELL_FUNCTION << 'EOF'
	lookup_shell() {
		export whichshell
		case ${ZSH_VERSION:-} in *.*) { whichshell=zsh;return;};;esac
		case ${BASH_VERSION:-} in *.*) { whichshell=bash;return;};;esac
		case "${VERSION:-}" in *zsh*) { whichshell=zsh;return;};;esac
		case "${SH_VERSION:-}" in *PD*) { whichshell=sh;return;};;esac
		case "${KSH_VERSION:-}" in *PD*|*MIRBSD*) { whichshell=ksh;return;};;esac
	}
EOF
  eval "${LOOKUP_SHELL_FUNCTION}"
  # shellcheck enable=all
  lookup_shell
  set -e
  is_zsh() {
    [[ ${whichshell:-} == "zsh"   ]]
  }
  if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
    # We are running in zsh
    eval "${GET_LIB_DIR_IN_ZSH}"
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi

# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${OSX_UTILITY_FUNCTIONS_LOADED:=1}"

# Installs Homebrew if it is not already installed.
#
# This function is called during the setup process if the user has opted to
# install Homebrew. It checks if Homebrew is already installed, and if it is,
# then it does nothing. If Homebrew is not installed, then this function
# installs Homebrew.
#
# This function requires that the user has passwordless sudo access, so it
# returns 1 if the user does not have passwordless sudo access.
#
# This function is called by the setup script.
#
# Args:
#   None
#
# Returns:
#   0 if Homebrew was successfully installed or if it was already installed
#   1 if Homebrew was not installed and the user does not have passwordless sudo access
install_homebrew() {
  if command_exists brew; then
    info_log "Homebrew already installed"
    return 0
  fi
  has_passwordless_sudo_access || return 1
  NONINTERACTIVE=1 sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# Installs GNU coreutils, which come with the "real" ls, cp, etc. that are
# gnu-compatible. This is necessary for some of the brew formulae.
install_coreutils() {
  if command_exists brew; then
    brew_has coreutils || NONINTERACTIVE=1 brew install coreutils || true
    add_to_path "/usr/local/opt/coreutils/libexec/gnubin"
  fi
}

brew_app_directory() {
  if command_exists brew; then
    if [[ $# -eq 0 ]]; then
      return 1
    else
      if command_exists readlink; then
        readlink -f "$(brew --prefix "$@")"
      else
        for app in "$@"; do
          echo "$(brew --cellar "${app}")/$(brew info --json "${app}" | jq -r '.[0].installed[0].version')"
        done
      fi
    fi
  fi
}

# is_quarantined()
#
#   Description: Check if a file has the com.apple.quarantine extended attribute
#
#   Parameters:
#     $1 - The path to the file
#
#   Returns:
#     0 if the file has the extended attribute
#     1 if the file does not have the extended attribute
#     2 if the path is not specified
#     3 if the path is not a file
#     4 if the path is a directory
#
#   Examples:
#     is_quarantined "/tmp/test.txt"
#       returns 0 if the file has the extended attribute
#
#     is_quarantined "/tmp/test.txt"
#       returns 1 if the file does not have the extended attribute
#
#     is_quarantined
#       returns 2 if the path is not specified
#
#     is_quarantined "/tmp/"
#       returns 3 if the path is not a file
#
#     is_quarantined "/tmp"
#       returns 4 if the path is a directory
#
is_quarantined() {
  local path="${1:-}"
  if [[ -n ${path} ]]; then
    if [[ -f ${path} ]]; then
      xattr -p com.apple.quarantine "${path}" > /dev/null 2>&1
    elif [[ -d ${path} ]]; then
      error_log "is_quarantined(): Path is a directory"
    else
      error_log "is_quarantined(): Path is not a file"
    fi
  else
    error_log "is_quarantined(): Path is not specified"
  fi
}

# Removes the quarantine attribute from a file or directory.
# If no path is provided, the quarantine attribute for the entire system is removed.
#
# Arguments:
#   path: path to the file or directory to remove the quarantine attribute from
#
# Returns:
#   None
remove_quarantine() {
  local path="${1:-}"
  local SUDO=""
  if has_passwordless_sudo_access; then
    SUDO="sudo"
  fi
  # Allow the user to run the downloaded file
  ${SUDO} defaults write com.apple.LaunchServices LSQuarantine -bool NO || true
  ${SUDO} defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool NO || true

  if [[ -n ${path} ]]; then
    if [[ -f ${path} ]]; then
      if is_quarantined "${path}"; then
        ${SUDO} xattr -d com.apple.quarantine "${path}" || true
      fi
    elif [[ -d ${path} ]]; then
      ${SUDO} xattr -rd com.apple.quarantine "${path}" || true
    fi
  fi
}
