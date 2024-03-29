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
: "${GITHUB_CORE_FUNCTIONS_LOADED:=1}"

[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"

check_if_tag_created() {
  if ! git describe --exact-match > /dev/null 2>&1; then
    git fetch --depth=1 origin "+refs/tags/*:refs/tags/*" > /dev/null 2>&1 || return 1
    git describe --exact-match > /dev/null 2>&1 || return 1
  fi
}

get_tag_name() {
  git describe --exact-match 2> /dev/null
}

set_tag_as_output_if_available() {
  if check_if_tag_created; then
    set_env GITHUB_TAG "$(get_tag_name)"
    set_output tag "${GITHUB_TAG}"
  else
    set_output tag "unknown"
  fi
}

get_prerelease_suffix() {
  if [[ $# -eq 0 ]]; then
    echo "RC"
  else
    SUFFIX="$(echo "${1}" | sed -e 's;^refs/.*/;;g' -e 's;^.*/;;g')"
    export SUFFIX
  fi
}

check_if_on_release_branch() {
  if [[ -n ${1:-${GITHUB_REF}} ]] && [[ -n ${2:-${RELEASE_BRANCH}} ]]; then
    local raw_ref="${1:-${GITHUB_REF}}"
    local -r ref="${raw_ref//refs\/heads\//}"
    local raw_release_branch="${2:-${RELEASE_BRANCH}}"
    local -r release="${raw_release_branch//refs\/heads\//}"

    if [[ ${ref} == "${release}" ]]; then
      set_output on true
      set_env ON_RELEASE_BRANCH true
      set_env BUMP_VERSION "${BUMP_VERSION:-patch}"
    else
      set_output on false
      set_env ON_RELEASE_BRANCH false
      set_env BUMP_VERSION "${BUMP_VERSION:-build}"
    fi
  else
    error_log "You need to provide a branch name to check"
  fi
}

running_in_github_actions() {
  [[ -n ${GITHUB_ACTIONS:-} ]]
}
running_in_github_actions || GITHUB_STEP_SUMMARY="summary.md"

step_summary() (
  set +x +e
  echo "${*}" >> "${GITHUB_STEP_SUMMARY}"
  return 0
)

group_start() {
  local name="$1"
  if [[ -n ${GITHUB_ACTIONS+x} ]]; then
    echo "::group::${name}"
  else
    info_log "🍔 Log group start: ${name}"
  fi
}
group_end() {
  if [[ -n ${GITHUB_ACTIONS+x} ]]; then
    echo "::endgroup::"
  else
    info_log "🍟 Log group end"
  fi
}

step_summary_display() {
  cat "${GITHUB_STEP_SUMMARY}"
  return 0
}

step_summary_title() (
  if [[ ${#} -eq 0 ]]; then
    # Show existing title
    sed -n '1 p' "${GITHUB_STEP_SUMMARY}" 2> /dev/null || true
  else
    local title="${*}"
    title="# $(titlecase "${title}")"
    if [[ ! -f ${GITHUB_STEP_SUMMARY} ]]; then
      # No File, create it and add the Title
      echo "${title}" > "${GITHUB_STEP_SUMMARY}"
    else
      # File exists, Add or Update the Title
      SEDARGS=(-i)
      is_darwin && SEDARGS+=("''")
      info_log "Setting Step Summary Title to: ${title}"
      if sed -n '1 p' "${GITHUB_STEP_SUMMARY}" 2> /dev/null | grep -q -e "^#"; then
        # Update title
        sed "${SEDARGS[@]}" "1 s/^.*$/${title}/" "${GITHUB_STEP_SUMMARY}" || true
      else
        # Insert title at top
        sed "${SEDARGS[@]}" "1 i ${title}" "${GITHUB_STEP_SUMMARY}" || true
      fi
    fi
  fi
  return 0
)

step_summary_append() (
  set +x +e
  info_log "${0}(): Appending to Step Summary: ${*}"
  running_in_github_actions || GITHUB_STEP_SUMMARY="summary.md"
  echo "${*}" >> "${GITHUB_STEP_SUMMARY}"
  return 0
)

set_env() {
  local key="$1"
  local value="$2"
  if [[ $# -ne 2 ]]; then
    if [[ $# -eq 1 ]] && grep -q -i -E "^(\w[-\w_\d]+)=(.*)"; then
      # Single argument is a key=value pair
      local key="${1%%=*}"
      local value="${1#*=}"
    else
      error_log "${0}: You need to provide two arguments. Provided args ${*}"
      return 1
    fi
  fi
  if running_in_ci; then
    : "${GITHUB_ENV:="./env.environment.local.github"}"
    if [[ -z ${ACT:-}   ]]; then
      touch "${GITHUB_ENV}"
      multiline_variable "${GITHUB_ENV}" "${key}" "${value}"
    else
      # ACT is used for testing GitHub Actions locally
      echo "set-env name=${1}::${2}"
      echo "::set-env name=${1}::${2}"
    fi

  fi
  export "${key}"="${value}"
  debug "Environment Variable set: ${key}=${value}"
  return 0
}

set_output() {
  local key="$1"
  local value="$2"
  if [[ $# -ne 2 ]]; then
    if [[ $# -eq 1 ]] && grep -q -i -E "^(\w[-\w_\d]+)=(.*)"; then
      # Single argument is a key=value pair
      local key="${1%%=*}"
      local value="${1#*=}"
    else
      error_log "${0}: You need to provide two arguments. Provided args ${*}"
      return 1
    fi
  fi

  if running_in_github_actions; then
    : "${GITHUB_OUTPUT:="./env.output.local.github"}"
    if [[ -z ${ACT:-}   ]]; then
      touch "${GITHUB_OUTPUT}"
      multiline_variable "${GITHUB_OUTPUT}" "${key}" "${value}"
      debug "Output Variable set: ${key}=${value}"
    else
      # ACT is used for testing GitHub Actions locally
      echo "set-output name=${key}::${value}"
      echo "::set-output name=${key}::${value}"
    fi
  else
    debug "Not in CI, Output Variable not set: ${key}=${value}"
  fi
}

set_github_state() {
  if [[ $# -ne 2 ]]; then
    error_log "${0}: You need to provide two arguments. Provided args ${*}"
    return 1
  fi
  if running_in_github_actions; then
    : "${GITHUB_STATE:="./env.state.local.github"}"
    touch "${GITHUB_STATE}"
    multiline_variable "${GITHUB_STATE}" "${1}" "${2}"
    debug "State Variable set: ${1}=${2}"
  else
    debug "Not in CI, State Variable not set: ${1}=${2}"
  fi
}

# add_to_path function moved to system_functions

get_java_version() {
  if [[ -f .java-version ]]; then
    JAVA_VERSION="$(awk '{print $1;}' .java-version)"
  else
    JAVA_VERSION="11.0"
  fi
  echo "Java Version is: ${JAVA_VERSION}"
  set_output version "${JAVA_VERSION}"
  set_output java_version "${JAVA_VERSION}"
}

set_build_framework_output() {
  if [[ -f "build.gradle" ]]; then
    set_output is gradle
  elif [[ -f "pom.xml" ]]; then
    set_output is maven
  fi
}

set_build_framework_env() {
  if [[ -f "build.gradle" ]]; then
    set_env FRAMEWORK gradle
  elif [[ -f "pom.xml" ]]; then
    set_env FRAMEWORK maven
  fi
}

escape_github_command_data() {
  # Escape the GitHub string variable character to %25
  # Escape any carrage returns to %0D
  # Escape any remaining newlines to %0A
  local -r data="${1}"
  printf '%s' "${data}" | perl -ne '$_ =~ s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g;print;'
}

escape_github_command_property() {
  # Escape the GitHub string variable character to %25
  # Escape any carrage returns to %0D
  # Escape any remaining newlines to %0A
  # Escape the colons to %3A
  # Escape the commas to %2C
  local -r data="${1}"
  printf '%s' "${data}" | perl -ne '$_ =~ s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g;s/:/%3A/g;s/,/%2C/g;print;'
}
multiline_variable() {
  local -r variable_file="${1}"
  local -r variable_name="${2}"
  if [[ $# -eq 3 ]]; then
    local -r delimiter="$(openssl rand -hex 8)"
    local -r variable_value="${3}"
    printf "%s<<%s\n%s\n%s\n" "${variable_name}" "${delimiter}" "${variable_value:-}" "${delimiter}" >> "${variable_file}"
  else
    error_log "You need to provide a variable name and value. Args: ${*}"
  fi
}
get_last_github_author_email() {
  if command_exists jq && [[ -f ${GITHUB_EVENT_PATH:-} ]]; then
    jq -r --arg default "$1" '.check_suite // .workflow_run // .sender // . | .head_commit // .commit.commit // . | .author.email // .pusher.email // .email // "$default"' "${GITHUB_EVENT_PATH:-}"
  fi
}
get_last_github_author_name() {
  if command_exists jq && [[ -f ${GITHUB_EVENT_PATH:-} ]]; then
    jq -r '.pull_request // .check_suite // .workflow_run // .issue // .sender // .commit // .repository // . | .head_commit // .commit // . | .author.name // .pusher.name // .login // .user.login // .owner.login // ""' "${GITHUB_EVENT_PATH:-}"
  fi
}

add_github_to_known_hosts() {
  mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
}
