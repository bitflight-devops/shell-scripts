#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z ${SCRIPTS_LIB_DIR:-}   ]]; then
  LC_ALL=C
  export LC_ALL
  set +e

  # by using a HEREDOC, we are disabling shellcheck and shfmt

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
    [[ ${whichshell:-} == "zsh" ]]
  }
  # shellcheck disable=SC2277,SC2299,SC2250,SC2296,SC2298,SC2310
  if command_exists zsh && [[ ${whichshell} == "zsh"   ]]; then
    # We are running in zsh
    if [[ -f "${0:a:h}/bootstrap.zsh" ]]; then
      source "${0:a:h}/bootstrap.zsh"
    else
      SCRIPTS_LIB_DIR="${0:a:h}"
      SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
      if [[ -f "${SCRIPTS_LIB_DIR:-}/lib/.scripts.lib.md" ]]; then
        SCRIPTS_LIB_DIR="${SCRIPTS_LIB_DIR:-}/lib"
      fi
      IN_ZSH=true
      IN_BASH=false
    fi
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
    IN_BASH=true
    IN_ZSH=false
  fi
fi

# End Lookup Current Script Directory
##########################################################
: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${SHELL_SCRIPTS_BOOTSTRAP_LOADED:=1}"

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
  else
    error_log "unable to find: source '${SCRIPTS_LIB_DIR}/${library}'"
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
  if [[ -n ${SCRIPTS_LIB_DIR:-} ]] && [[ -d ${SCRIPTS_LIB_DIR} ]]; then
    for library in "${LIBRARIES[@]}"; do
      load_library "${library}" || bootstrap_exec error "Library ${library} not found"
    done
  else
    error_log "Environment variables BFD_REPOSITORY or SCRIPTS_LIB_DIR not set"
  fi
}

unload_libraries() {
  declare -a LIBRARIES=("$@")
  if [[ -n ${SCRIPTS_LIB_DIR:-} ]] && [[ -d ${SCRIPTS_LIB_DIR} ]]; then
    for library in "${LIBRARIES[@]}"; do
      unload_library "${library}" || bootstrap_exec error "Library ${library} not found"
    done
  else
    error_log "Environment variables BFD_REPOSITORY or SCRIPTS_LIB_DIR not set"
  fi
}

is_sourced() {
  if "${IN_ZSH:-false}"; then
    [[ -n ${ZSH_EVAL_CONTEXT:-} ]] && [[ ${ZSH_EVAL_CONTEXT} =~ :file$ ]]
  elif "${IN_BASH:-false}"; then
    [[ ${BASH_SOURCE[1]} != "${0}"   ]]
  fi
}

logs_as_comments() {
    if ! is_sourced; then
      printf '# '
  fi
}
if ! command_exists info_log; then
  info_log() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    logs_as_comments
    printf '%sINFO: %s%s\n' "${c}" "${*}" "${e}"
  }
fi
if ! command_exists error_log; then
  error_log() {
    local c=$'\e[32m'
    local e=$'\e[0m'
    logs_as_comments
    printf '%sERROR: %s%s\n' "${c}" "${*}" "${e}" >&2
  }
fi
if [[ ${#PROVIDED_LIBRARY_LIST[@]} -eq 0 ]]; then
  LOAD_LIBRARIES=("${AVAILABLE_LIBRARIES[@]}")
else
  LOAD_LIBRARIES=("${PROVIDED_LIBRARY_LIST[@]}")
fi

if [[ -z ${UNLOAD_LIBRARIES-} ]]; then
  if is_sourced; then
    bootstrap_exec info_log "Loading libraries..."
  fi
    SOURCED_LIBRARIES="$(load_libraries "${LOAD_LIBRARIES[@]}")"
    sourcing_errored=$?
fi
if is_sourced; then
  if [[ -n ${UNLOAD_LIBRARIES-} ]]; then
    eval "$(unload_libraries "${LOAD_LIBRARIES[@]}")" || sourcing_errored=$?
  else
    eval "${SOURCED_LIBRARIES}" || sourcing_errored=$?
  fi
else
  # We are running as a script
  # So echo the commands
  if [[ -n ${UNLOAD_LIBRARIES-} ]]; then
    unload_libraries "${LOAD_LIBRARIES[@]}" || sourcing_errored=$?
  elif [[ ${sourcing_errored} -eq 0 ]]; then
    load_libraries "${LOAD_LIBRARIES[@]}" || sourcing_errored=$?
  fi
fi
if [[ ${sourcing_errored} -eq 0 ]]; then
  if is_sourced; then
    whichloaded="$(printf ' -> %s\n' "${LOAD_LIBRARIES[@]}")"
    bootstrap_exec info_log "Libraries loaded\n${whichloaded}"
  fi
else
  error_log "Failed to load libraries"
fi
unset LOAD_LIBRARIES
unset AVAILABLE_LIBRARIES
unset PROVIDED_LIBRARY_LIST
