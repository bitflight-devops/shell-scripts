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
    [[ "${whichshell:-}" == "zsh" ]]
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
: "${STRING_VARIABLES_LOADED:=1}"

[[ -z ${COLOR_AND_EMOJI_VARIABLES_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/color_and_emoji_variables.sh"

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

uppercase() {
    tr '[:lower:]' '[:upper:]' <<< "${*}"
}

lowercase() {
    tr '[:upper:]' '[:lower:]' <<< "${*}"
}

iscolorcode() {
    grep -q -E $'\e\\[''(?:[0-9]{1,3})(?:(?:;[0-9]{1,3})*)?[mGK]' <<< "$1"
}

colorcode() {
  local -r color="${1}"
  if iscolorcode "${color}"; then
    perl -pe 's/(^\s*|\s*$)/Y/g;' <<< "${color}"
  elif [[ -n ${color:-} ]]; then
    local -r color_var_name="$(uppercase "${color}")"
    eval 'local resolved_color="${'"${color_var_name}"':-}"'
    if [[ -n ${resolved_color:-} ]] && iscolorcode "${colorcode}"; then
      perl -pe 's/(^\s*|\s*$)//gm;' <<< "${colorcode}"
    elif [[ -z ${DEBUG:-} ]]; then
      printf '%s' "${resolved_color}"
    else
      printf ''
    fi
  fi
}

stripcolor() {
  # shellcheck disable=SC2001
  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" <<< "${*}"
}

if [[ -f "${SCRIPTS_LIB_DIR}/trim_keeping_colors.perl" ]] && command_exists perl; then
  trim() {
    "${SCRIPTS_LIB_DIR}/trim_keeping_colors.perl" <<< "${*}"
  }
else
  trim() {
    sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "${*}"
  }
fi
# Alias for trim
trimString() {
  trim "${*}"
}

# Is provided string empty
empty() {
  if [[ -z "$(tr -d '[:space:]' <<< "${*}")" ]]; then
    echo 'true' && return 0
  else
    echo 'false' && return 1
  fi
}

# Alias for empty
isEmptyString() {
  squash_output empty "${*}"
}

trim_dash() {
  sed 's/^[- ]*//g;s/[- ]*$//g' <<< "${*}"
}

uppercase() {
  tr '[:lower:]' '[:upper:]' <<< "${*}"
}

lowercase() {
  tr '[:upper:]' '[:lower:]' <<< "${*}"
}

squash_spaces() {
  tr -s '[:space:]' ' ' <<< "${*}"
}

# Remove Starting # from the string
# Trim leading and trailing spaces
# Uppercase the first letter of each word in the string
# Remove duplicated whitespace
# Set the Jira Ticket Keys to Uppercase
# Do not modify words that start with non-alphanumeric characters
titlecase() {
  local string="$(trim "${*###}")"

  perl -pe 's/^#+//g;s/(^\h*|\h*$)//g;s/(\w)([\w'"'"']*)/\U$1\L$2/gm;tr/ //s;s/([a-zA-Z]{3,8}-[0-9]+)/\U$1/g;' <<< "${string}"
}
