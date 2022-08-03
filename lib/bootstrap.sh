#!/usr/bin/env bash
if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi

if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if command -v zsh >/dev/null 2>&1 && [[ $(${SHELL} -c 'echo ${ZSH_VERSION}') != '' ]] || { command -v ps >/dev/null 2>&1 && grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; }; then
    # We are running in zsh
    # shellcheck disable=SC2296
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  fi
fi

export SCRIPTS_LIB_DIR
export BFD_REPOSITORY="${BFD_REPOSITORY:-${SCRIPTS_LIB_DIR%/lib}}"
# shellcheck disable=SC2034
SHELL_SCRIPTS_BOOTSTRAP_LOADED=1

declare -a AVAILABLE_LIBRARIES=(
  "color_and_emoji_variables"
  "elasticbeanstalk_functions"
  "general_utility_functions"
  "github_core_functions"
  "log_functions"
  "osx_utility_functions"
  "remote_utility_functions"
  "string_functions"
  "system_functions"
  "trace_functions"
  "yaml_functions"
  "java_functions"
)

# PROVIDED_ARGS=("${@}")
# PROVIDED_LIBRARY_LIST=()
# if [[ ${#PROVIDED_ARGS} -gt 0 ]]; then
#   for arg in "${PROVIDED_ARGS[@]}"; do
#     if [[ ${arg} =~ ^(--debug|-d)$ ]]; then
#       export DEBUG=1
#     elif [[ ${arg} =~ ^(--silent|-s)$ ]]; then
#       export SILENT_BOOTSTRAP=1
#     elif [[ ${AVAILABLE_LIBRARIES[*]} =~ ("${arg}") ]]; then
#       PROVIDED_LIBRARY_LIST+=("${arg}")
#     fi
#   done
# fi

run_quietly() {
  if [[ -z ${SHELL_SCRIPTS_QUIET:-} ]] || [[ -n ${DEBUG:-} ]]; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

load_library() {
  local library="${1%.sh}.sh"
  if [[ -f "${SCRIPTS_LIB_DIR}/${library}" ]]; then
    echo "source '${SCRIPTS_LIB_DIR}/${library}'"
    return 0
  fi
  return 1
}

load_libraries() {
  declare -a LIBRARIES=("$@")
  if [[ -n ${SCRIPTS_LIB_DIR:-} ]] && [[ -x ${SCRIPTS_LIB_DIR} ]]; then
    for library in "${LIBRARIES[@]}"; do
      load_library "${library}" || run_quietly error "Library ${library} not found"
    done
  else
    error "Environment variables BFD_REPOSITORY or SCRIPTS_LIB_DIR not set"
  fi
}

if load_library log_functions >/dev/null 2>&1; then
  eval "$(load_library log_functions)"
fi

if [[ $(type -t log_output) != 'function' ]]; then
  function info() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    printf '%s\n' "${c}INFO : ${*}${e}"
  }
  function error() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    printf '%s\n' "${c}ERROR: ${*}${e}" >&2
  }
fi

if [[ $# -eq 0 ]]; then
  LOAD_LIBRARIES=("${AVAILABLE_LIBRARIES[@]}")
else
  LOAD_LIBRARIES=("${PROVIDED_LIBRARY_LIST[@]}")
fi

run_quietly info "Loading libraries..."
if load_libraries "${LOAD_LIBRARIES[@]}" >/dev/null && eval "$(load_libraries "${LOAD_LIBRARIES[@]}")"; then
  run_quietly info "Libraries loaded\n$(printf ' -> %s\n' "${LOAD_LIBRARIES[@]}")"
else
  error "Failed to load libraries"
fi
unset LOAD_LIBRARIES
unset AVAILABLE_LIBRARIES
