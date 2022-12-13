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
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi
# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${TRACE_FUNCTIONS_LOADED:=1}"

xtrace() {
  # Print the line as if xtrace was turned on, using sed to filter out
  # the extra colon character and the following "set +x" line.
  ( 
    set -x
    # Colon is a no-op in bash, so nothing will execute.
    "$@"
    set +x
  ) 2>&1 | sed -e 's/^[+]:/+/g' -e '/^[+]*set +x$/d' 1>&2
  # Execute the original line unmolested
  # "$@"
}
