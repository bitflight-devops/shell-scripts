#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z "${SCRIPTS_LIB_DIR:-}" ]]; then
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
  read -r -d '' LOOKUP_SHELL_FUNCTION <<- 'EOF'
	lookup_shell() {
		export whichshell
		case $ZSH_VERSION in *.*) { whichshell=zsh;return;};;esac
		case $BASH_VERSION in *.*) { whichshell=bash;return;};;esac
		case "$VERSION" in *zsh*) { whichshell=zsh;return;};;esac
		case "$SH_VERSION" in *PD*) { whichshell=sh;return;};;esac
		case "$KSH_VERSION" in *PD*|*MIRBSD*) { whichshell=ksh;return;};;esac
	}
	EOF
  set -e
  eval "${LOOKUP_SHELL_FUNCTION}"
  # shellcheck enable=all
  lookup_shell
  if command_exists zsh && [[ "${whichshell}" == "zsh" ]]; then
    # We are running in zsh
    eval "${GET_LIB_DIR_IN_ZSH}"
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi
export SCRIPTS_LIB_DIR

# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${JAVA_FUNCTIONS_LOADED:=1}"

[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"
[[ -z ${GENERAL_UTILITY_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/general_utility_functions.sh"
[[ -z ${REMOTE_UTILITY_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/remote_utility_functions.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"

install_xmllint() {
  if ! command_exists xmllint; then
    install_app libxml2-utils
  fi
}

pom_buildnumber() {
  if [[ $# -eq 0 ]]; then
    install_xmllint
    xmllint --xpath '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="buildnumber"]/text()' pom.xml
  elif [[ $# -eq 1 ]]; then
    echo "Build set to $1"
    sed -i -e "1,/<buildnumber>.*<\/buildnumber>/ s/<buildnumber>.*<\/buildnumber>/<buildnumber>$1<\/buildnumber>/" pom.xml
    command_exists git && git add pom.xml
  else
    echo "Too many parameters"
  fi
}
