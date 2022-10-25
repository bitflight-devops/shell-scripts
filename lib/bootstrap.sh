#!/usr/bin/env bash

if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -d ${BFD_REPOSITORY} ]]; then
  : "${SCRIPTS_LIB_DIR:="${BFD_REPOSITORY}/lib"}"
fi

if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if command -v zsh > /dev/null 2>&1 && [[ $(${SHELL} -c 'echo ${ZSH_VERSION}') != '' ]] || {
     command -v ps > /dev/null 2>&1 && grep -q 'zsh' <<< "$(ps -c -ocomm= -p $$)"
  }; then
    # We are running in zsh
    # shellcheck disable=SC2296,SC2299,SC2250,SC2296,SC2299,SC2277,SC2298
    # trunk-ignore(shfmt/parse)
    0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
    # shellcheck disable=SC2296,SC2299,SC2250,SC2296,SC2299,SC2277,SC2298
    0="${${(M)0:#/*}:-$PWD/$0}"
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
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

PROVIDED_ARGS=("${@}")
PROVIDED_LIBRARY_LIST=()
if [[ ${#PROVIDED_ARGS} -gt 0 ]]; then
  for arg in "${PROVIDED_ARGS[@]}"; do
    if [[ ${arg} =~ ^(--debug|-d)$ ]]; then
      DEBUG=1
    elif [[ ${arg} =~ ^(--unload|--uninstall|-u)$ ]]; then
      UNLOAD_LIBRARIES=1
    elif [[ ${arg} =~ ^(--silent|-s|-q)$ ]]; then
      SHELL_SCRIPTS_QUIET=1
    elif [[ ${AVAILABLE_LIBRARIES[*]} =~ ("${arg}") ]]; then
      PROVIDED_LIBRARY_LIST+=("${arg}")
    fi
  done
fi

bootstrap_exec() {
  if [[ -z ${SHELL_SCRIPTS_QUIET:-} ]] || [[ -n ${DEBUG:-} ]]; then
    "$@"
  else
    "$@" > /dev/null 2>&1
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

unload_library() {
  local library="${1%.sh}.sh"
  if [[ -f "${SCRIPTS_LIB_DIR}/${library}" ]]; then
    # shellcheck disable=SC2046
    echo "unset $(perl -ne 'print "$1 " if /(?:^|\s+)(?:function\s+)?(.*)(?:\(\)\s+{)/' "${SCRIPTS_LIB_DIR}/${library}" 2> /dev/null)"
  fi
}

load_libraries() {
  declare -a LIBRARIES=("$@")
  if [[ -n ${SCRIPTS_LIB_DIR:-} ]] && [[ -x ${SCRIPTS_LIB_DIR} ]]; then
    for library in "${LIBRARIES[@]}"; do
      load_library "${library}" || bootstrap_exec error "Library ${library} not found"
    done
  else
    error "Environment variables BFD_REPOSITORY or SCRIPTS_LIB_DIR not set"
  fi
}

unload_libraries() {
  declare -a LIBRARIES=("$@")
  if [[ -n ${SCRIPTS_LIB_DIR:-} ]] && [[ -x ${SCRIPTS_LIB_DIR} ]]; then
    for library in "${LIBRARIES[@]}"; do
      unload_library "${library}" || bootstrap_exec error "Library ${library} not found"
    done
  else
    error "Environment variables BFD_REPOSITORY or SCRIPTS_LIB_DIR not set"
  fi
}

is_sourced() {
  if [[ "${SHELL}" =~ zsh ]]; then
    [[ -n ${ZSH_EVAL_CONTEXT:-} ]] && [[ ${ZSH_EVAL_CONTEXT} =~ :file$ ]]
  else
    [[ "${FUNCNAME[1]}" == source ]] && [[ "${BASH_SOURCE[1]}" != "${0}" ]]
  fi
}

logs_as_comments() {
    if ! is_sourced; then
      printf '# '
  fi
}

function info() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    logs_as_comments
    printf '%sINFO: %s%s\n' "${c}" "${*}" "${e}"
}

function error() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    logs_as_comments
    printf '%sERROR: %s%s\n' "${c}" "${*}" "${e}" >&2
}

if [[ ${#PROVIDED_LIBRARY_LIST[@]} -eq 0 ]]; then
  LOAD_LIBRARIES=("${AVAILABLE_LIBRARIES[@]}")
else
  LOAD_LIBRARIES=("${PROVIDED_LIBRARY_LIST[@]}")
fi
if is_sourced; then
  if [[ -n ${UNLOAD_LIBRARIES-} ]]; then
    eval "$(unload_libraries "${LOAD_LIBRARIES[@]}")"
  else
    bootstrap_exec info "Loading libraries..."
    if load_libraries "${LOAD_LIBRARIES[@]}" > /dev/null && eval "$(load_libraries "${LOAD_LIBRARIES[@]}")"; then
      bootstrap_exec info "Libraries loaded\n$(printf ' -> %s\n' "${LOAD_LIBRARIES[@]}")"
    else
      error "Failed to load libraries"
    fi
  fi
else
  # We are running as a script
  # So echo the commands
  if [[ -n ${UNLOAD_LIBRARIES-} ]]; then
    unload_libraries "${LOAD_LIBRARIES[@]}"
  else
    if load_libraries "${LOAD_LIBRARIES[@]}" > /dev/null; then
      load_libraries "${LOAD_LIBRARIES[@]}"
    else
      error "Failed to load libraries"
    fi
  fi
fi
unset LOAD_LIBRARIES
unset AVAILABLE_LIBRARIES
unset PROVIDED_LIBRARY_LIST
