#!/usr/bin/env bash
# Current Script Directory
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
export JAVA_FUNCTIONS_LOADED=1
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
