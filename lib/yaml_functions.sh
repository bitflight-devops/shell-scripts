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
: "${YAML_FUNCTIONS_LOADED:=1}"

parse_yaml() {
  local prefix=$2
  local s
  local w
  local fs
  s='[[:space:]]*'
  w='[a-zA-Z0-9_]*'
  fs="$(echo @ | tr @ '\034')"
  #shellcheck disable=SC1087
  sed -ne "s|^\(${s}\)\(${w}\)${s}:${s}\"\(.*\)\"${s}\$|\1${fs}\2${fs}\3|p" \
    -e "s|^\(${s}\)\(${w}\)${s}[:-]${s}\(.*\)${s}\$|\1${fs}\2${fs}\3|p" "$1" \
                                                                             | awk -F"${fs}" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=(\"%s\")\n", "'"${prefix}"'",vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}
