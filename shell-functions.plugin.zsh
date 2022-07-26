#!/usr/bin/env zsh

# Standarized $0 handling, following:
# https://z-shell.github.io/zsh-plugin-assessor/Zsh-Plugin-Standard
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
# Then ${0:h} to get plugin’s directory
# This plugin is called bitflight-devops/shell-scripts
# Available at https://github.com/bitflight-devops/shell-scripts
_shell_scripts_plugin_basedir="${0:h}"
if [[ (${+zsh_loaded_plugins} = 0 || ${zsh_loaded_plugins[-1]} != */shell-scripts) \
    && -z ${fpath[(r)${0:h}]} ]]
then
    fpath+=( "${_shell_scripts_plugin_basedir}/functions" )
fi

# Set BitFlight Repository Directory
BFD_REPOSITORY=${_shell_scripts_plugin_basedir}

if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -d ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi

if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if command -v zsh >/dev/null 2>&1 && [[ $(${SHELL} -c 'echo ${ZSH_VERSION}') != '' ]] || { command -v ps >/dev/null 2>&1 && grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; }; then
    # We are running in zsh
    # shellcheck disable=SC2296
    RAW_BFD_REPOSITORY="${0:a:h}"
    BFD_REPOSITORY="$(cd "${RAW_BFD_REPOSITORY}" >/dev/null 2>&1 && pwd -P)"
  else
    BFD_REPOSITORY="$(cd "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  fi
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi

# Standard Plugins Hash
# https://z.digitalclouds.dev/community/zsh_plugin_standard#standard-plugins-hash
typeset -gA Plugins
Plugins[BFD_REPOSITORY]="${_shell_scripts_plugin_basedir}"

autoload -Uz shell-scripts_plugin_load shell-scripts_plugin_unload
shell-scripts_plugin_load

