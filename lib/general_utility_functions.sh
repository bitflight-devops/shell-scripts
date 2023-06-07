#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }
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

if [[ -z ${SCRIPTS_LIB_DIR:-}   ]]; then
  LC_ALL=C
  export LC_ALL
  if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
    # We are running in zsh
    if [[ -f "${0:a:h}/bootstrap.zsh" ]]; then
      source "${0:a:h}/bootstrap.zsh"
    else
      SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
    fi
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi

if [[ -f "${SCRIPTS_LIB_DIR:-}/lib/.scripts.lib.md" ]]; then
  SCRIPTS_LIB_DIR="${SCRIPTS_LIB_DIR:-}/lib"
fi

if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
  IN_ZSH=true
  IN_BASH=false
elif command_exists bash && [[ ${whichshell:-} == "bash"   ]]; then
  IN_ZSH=false
  IN_BASH=true
fi

# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${GENERAL_UTILITY_FUNCTIONS_LOADED:=1}"

[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"

export BOOLEAN_TRUE="(true|on|yes|1)"
export BOOLEAN_FALSE="(false|off|no|0)"

isTrue() {
  grep -q -i -E "${BOOLEAN_TRUE}" <<< "${1}"
}

isFalse() {
  grep -q -i -E "${BOOLEAN_FALSE}" <<< "${1}"
}

squash_output() {
  "$@" > /dev/null 2>&1
}

run_quietly() {
  if in_quiet_mode; then
    "$@" > /dev/null 2>&1
  else
    "$@"
  fi
}

returnBoolean() {
  local value="${1}"
  if isTrue "${UTILITY_EMPTY_BOOLEAN_AS_FALSE:-false}"; then
    if [[ ${#value} -eq 0 ]]; then
      error_log "Non-boolean value"
      return 2
    fi
    if [[ ${value:-x} == "x" ]]; then
      # It falls back to the default x value, its empty
      error_log "Non-boolean value"
      return 2
    fi
  fi

  if isTrue "${value}"; then
    echo 'true' && return 0
  elif isFalse "${value}"; then
    echo 'false' && return 1
  else
    echo "Non-boolean value: ${value}"
    return 2
  fi
}

isBoolean() {
  local -r value="${1}"
  local errorMessage="${2}"

  if isTrue "${value}" || isFalse "${value}"; then
    return 0
  else
    if isEmptyString "${errorMessage}"; then
      errorMessage="'${value}' doesn't match ${BOOLEAN_TRUE} or ${BOOLEAN_TRUE}"
    fi
    error_log "${errorMessage}" && return 1
  fi
}

# Run the command given by "$@" in the background
silent_background() {
  if [[ ${whichshell} == "zsh"   ]]; then # zsh:  https://superuser.com/a/1285272/365890
    setopt local_options no_notify no_monitor
    "$@" &
  elif [[ ${whichshell} == "bash"   ]]; then # bash: https://stackoverflow.com/a/27340076/5353461
    { "$@" 2>&3 & } 3>&2 2> /dev/null
  else # Unknownness - just background it
    "$@" &
  fi
}

if ! command_exists realpath; then
  realpath() {
    readlink -f -- "$@"
  }
fi
