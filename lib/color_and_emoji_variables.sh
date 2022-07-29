#!/usr/bin/env bash
# Current Script Directory
if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
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
export COLOR_AND_EMOJI_VARIABLES_LOADED=1
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"

BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

if test -t 1 && command_exists tput && [[ $(tput colors) -gt 0 ]]; then
  export COLOR_BRIGHT_BLACK=$'\e[0;90m'
  export COLOR_BRIGHT_RED=$'\e[0;91m'
  export COLOR_BRIGHT_GREEN=$'\e[0;92m'
  export COLOR_BRIGHT_YELLOW=$'\e[0;93m'
  export COLOR_BRIGHT_BLUE=$'\e[0;94m'
  export COLOR_BRIGHT_MAGENTA=$'\e[0;95m'
  export COLOR_BRIGHT_CYAN=$'\e[0;96m'
  export COLOR_BRIGHT_WHITE=$'\e[0;97m'
  export COLOR_BLACK=$'\e[0;30m'
  export COLOR_RED=$'\e[0;31m'
  export COLOR_GREEN=$'\e[0;32m'
  export COLOR_YELLOW=$'\e[0;33m'
  export COLOR_BLUE=$'\e[0;34m'
  export COLOR_MAGENTA=$'\e[0;35m'
  export COLOR_CYAN=$'\e[0;36m'
  export COLOR_WHITE=$'\e[0;37m'
  export COLOR_BOLD_BLACK=$'\e[1;30m'
  export COLOR_BOLD_RED=$'\e[1;31m'
  export COLOR_BOLD_GREEN=$'\e[1;32m'
  export COLOR_BOLD_YELLOW=$'\e[1;33m'
  export COLOR_BOLD_BLUE=$'\e[1;34m'
  export COLOR_BOLD_MAGENTA=$'\e[1;35m'
  export COLOR_BOLD_CYAN=$'\e[1;36m'
  export COLOR_BOLD_WHITE=$'\e[1;37m'
  export COLOR_BOLD=$'\e[1m'
  export COLOR_BOLD_YELLOW=$'\e[1;33m'
  export COLOR_RESET=$'\e[0m'
  export CLEAR_SCREEN="$(tput rc)"
fi

export HOURGLASS_IN_PROGRESS=$'⏳' # ⏳ hourglass in progress
export HOURGLASS_DONE=$'⌛'        # ⌛ hourglass done
export CHECK_MARK_BUTTON=$'✅'     # ✅ check mark button
export CROSS_MARK=$'❌'            # ❌ cross mark
