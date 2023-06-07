#!/usr/bin/env zsh
# We are running in zsh
# 0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
# 0="${${(M)0:#/*}:-$PWD/$0}"
SCRIPTS_LIB_DIR="${0:a:h}"
SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
if [[ -f "${SCRIPTS_LIB_DIR:-}/lib/.scripts.lib.md" ]]; then
  SCRIPTS_LIB_DIR="${SCRIPTS_LIB_DIR:-}/lib"
fi
IN_ZSH=true
IN_BASH=false
