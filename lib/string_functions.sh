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
    [[ ${whichshell:-} == "zsh"   ]]
  }
  if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
    # We are running in zsh
    eval "${GET_LIB_DIR_IN_ZSH}"
    IN_ZSH=true
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
    IN_BASH=true
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
bash_version() {
  local as_number="${1:-false}"
  if command_exists bash; then
    local available_bash_version
    local ret=0
    if [[ -z ${BASH_VERSION:-} ]]; then
      available_bash_version="$(bash --version | head -n1 | cut -d' ' -f4 | cut -d'(' -f1)" || ret=$?
    else
      available_bash_version="${BASH_VERSION//\(*/}"
    fi
    if [[ ${ret} -ne 0 ]]; then
      available_bash_version="0.0.0"
    fi
    if [[ ${as_number} == "true" ]]; then
      printf "%d%-0.2d%-0.2d\n" ${available_bash_version//./ }
    else
      printf "%s\n" "${available_bash_version}"
    fi
  fi
}

AVAILABLE_BASH_VERSION="$(bash_version)"
AVAILABLE_BASH_VERSION_NUMBER="$(bash_version true)"
BASH_VERSION_4_OR_GREATER=false
[[ ${AVAILABLE_BASH_VERSION_NUMBER:-0} -gt 40000 ]] && BASH_VERSION_4_OR_GREATER=true

if "${BASH_VERSION_4_OR_GREATER:-false}"; then
  uppercase() {
    printf "%s\n" "${*^^}"
  }
  lowercase() {
    printf "%s\n" "${*,,}"
  }
  # reverse_case() {
  #   # Usage: reverse_case "string"
  #   local -r string="${*}"
  #   #printf "%s\n" "${string~~}"
  # }
else
  uppercase() {
    tr '[:lower:]' '[:upper:]' <<< "${*}"
  }
  lowercase() {
    tr '[:upper:]' '[:lower:]' <<< "${*}"
  }
fi
  reverse_case() {
    # Usage: reverse_case "string"
    perl -pe 'tr/A-Za-z/a-zA-Z/' <<< "${*}"
}

iscolorcode() {
  [[ $(perl -ne 'print "1" if($_ =~ /[[:cntrl:]]\[\d{1,3}(?:[;]\d{1,3})*[mGK]/)' <<< "$1") == 1 ]]
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

  if "${BASH_VERSION_4_OR_GREATER}"; then
    trim_string() {
      # Usage: trim "   example   string    "
      : "${1#"${1%%[![:space:]]*}"}"
      : "${_%"${_##*[![:space:]]}"}"
      printf "%s\n" "${_}"
  }
else
    trim_string() {
      sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "${*}"
  }
fi

  trim_keeping_colors() {
    if [[ -f "${SCRIPTS_LIB_DIR:-}/trim_keeping_colors.perl" ]] && command_exists perl; then
    "${SCRIPTS_LIB_DIR:-}/trim_keeping_colors.perl" <<< "${*}"
  else
      trim_string "${*}"
  fi
}

trim() {
  trim_keeping_colors "${*}"
}

if ${IN_BASH:-false}; then
  trim_quotes() {
    # Usage: trim_quotes "string"
    : "${1//\'/}"
    printf '%s\n' "${_//\"/}"
  }
else
  trim_quotes() {
    # Usage: trim_quotes "string"
    sed -e "s/'//g;s/\"//g" <<< "${*}"
  }
fi
# Alias for trim
trimString() {
  trim "${*}"
}

if "${BASH_VERSION_4_OR_GREATER:-false}"; then
  # shellcheck disable=SC2244
  remove_array_dups() {
    # Usage: remove_array_dups "array"
    declare -A tmp_array

    for i in "$@"; do
        [[ ${i} ]] && IFS=" " tmp_array["${i:- }"]=1
    done

    printf '%s\n' "${!tmp_array[@]}"
  }
else
  remove_array_dups() {
    # Usage: remove_array_dups "array"
    trim "$(printf "%s\n" "$@" | sort -u | tr '\n' ' ')"
  }
fi

if ${IN_BASH:-false}; then
  empty() {
    if [[ -z "${*// /}" ]]; then
      echo 'true' && return 0
    else
      echo 'false' && return 1
    fi
  }
else
  # Is provided string empty
  empty() {
    if [[ -z "$(tr -d '[:space:]' <<< "${*}")" ]]; then
      echo 'true' && return 0
    else
      echo 'false' && return 1
    fi
  }
fi
squash_output() {
  "$@" > /dev/null 2>&1
}
# Alias for empty, but doesn't print true/false
isEmptyString() {
  squash_output empty "${*}"
}

trim_dash() {
  sed 's/^[- ]*//g;s/[- ]*$//g' <<< "${*}"
}

# shellcheck disable=SC2086,SC2048
if ${IN_BASH:-false}; then
  # from https://github.com/dylanaraps/pure-bash-bible#trim-all-white-space-from-string-and-truncate-spaces
  squash_spaces() {
    # Usage: squash_spaces "   example   string    "
    set -f
    set -- ${*}
    printf "%s\n" "$*"
    set +f
  }
else
  squash_spaces() {
    local string="$(trim ${*})"
    tr -s '[:blank:]' ' ' <<< "${string}"
  }
fi

# from https://github.com/dylanaraps/pure-bash-bible#use-regex-on-a-string
if ${IN_BASH:-false}; then
  regex() {
    # Usage: regex "string" "regex"
    [[ $1 =~ $2 ]] && printf "%s\n" "${BASH_REMATCH[1]}"
  }
else
  regex() {
    # Usage: regex "string" "regex"
    local string="${1}"
    local regex="${2}"
    perl -ne 'print $1 if($_ =~ /'"${regex}"'/)' <<< "${string}"
  }
fi

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

# from https://github.com/dylanaraps/pure-bash-bible#split-a-string-on-a-delimiter
split() {
   # Usage: split "string" "delimiter"
   IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
   printf "%s\n" "${arr[@]}"
}
