#!/usr/bin/env bash
# Current Script Directory
if [[ -n ${BFD_REPOSITORY} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi
if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; then
    # shellcheck disable=SC2296
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  fi
fi
export SCRIPTS_LIB_DIR
export BFD_REPOSITORY="${BFD_REPOSITORY:-${SCRIPTS_LIB_DIR%/lib}}"
export GENERAL_UTILITY_FUNCTIONS_LOADED=1
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"

export BOOLEAN_TRUE="(true|on|yes|1)"
export BOOLEAN_FALSE="(false|off|no|0)"

isTrue() {
  grep -i -E "${BOOLEAN_TRUE}" <<<"${1}"
}

isFalse() {
  grep -i -E "${BOOLEAN_FALSE}" <<<"${1}"
}

returnBoolean() {
  local value="${1}"
  if grep -i -E "${BOOLEAN_TRUE}" <<<"${UTILITY_EMPTY_BOOLEAN_AS_FALSE:-false}"; then
    if [[ ${#value} -eq 0 ]]; then
      error "Non-boolean value"
      return 2
    fi
    if [[ ${value:-x} == "x" ]]; then
      # It falls back to the default x value, its empty
      error "Non-boolean value"
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
      errorMessage="'${value}' is not 'true' or 'false'"
    fi
    error "${errorMessage}" && return 1
  fi
}

# Run the command given by "$@" in the background
silent_background() {
  if [[ -n ${ZSH_VERSION} ]]; then # zsh:  https://superuser.com/a/1285272/365890
    setopt local_options no_notify no_monitor
    "$@" &
  elif [[ -n ${BASH_VERSION} ]]; then # bash: https://stackoverflow.com/a/27340076/5353461
    { "$@" 2>&3 & } 3>&2 2>/dev/null
  else # Unknownness - just background it
    "$@" &
  fi
}
