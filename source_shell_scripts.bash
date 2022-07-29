#!/usr/bin/env bash
# Parent Repository Directory
SHELL_SCRIPTS_GITHUB_REPOSITORY="bitflight-devops/shell-scripts"
BASE_INSTALL_DIR="${HOME}/.config/${SHELL_SCRIPTS_GITHUB_REPOSITORY}"
SCRIPTS_LIB_DIR_FOUND=0
is_scripts_lib_dir() { [[ -f "${1}/.scripts.lib.md" ]]; }
# Current Script Directory
if [[ -n ${BFD_REPOSITORY} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi
if [[ -z ${SCRIPTS_LIB_DIR} ]]; then
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
# Check if the SCRIPTS_LIB_DIR is actually in the lib repository folder
if is_scripts_lib_dir "${SCRIPTS_LIB_DIR}"; then
  SCRIPTS_LIB_DIR_FOUND=1
else
  # Are we in the root of the repo directory?
  if is_scripts_lib_dir "${SCRIPTS_LIB_DIR}"/lib; then
    SCRIPTS_LIB_DIR="${SCRIPTS_LIB_DIR}"/lib
    SCRIPTS_LIB_DIR_FOUND=1
  else
    # Or are we in a child directory of the git repository?
    if command_exists git; then
      GIT_BASE_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
      command_exists readlink && GIT_BASE_DIR="$(readlink -f "${GIT_BASE_DIR}" 2>/dev/null)"
    elif [[ -f ${SCRIPTS_LIB_DIR}/.git/config ]] && grep -q "$(basename "${SHELL_SCRIPTS_GITHUB_REPOSITORY}")" "${SCRIPTS_LIB_DIR}/.git/config"; then
      # No git binary, but still in the git repository folder?
      GIT_BASE_DIR="${SCRIPTS_LIB_DIR}"
    fi

    if [[ -n ${GIT_BASE_DIR} ]] && is_scripts_lib_dir "${GIT_BASE_DIR}/lib"; then
      SCRIPTS_LIB_DIR="${GIT_BASE_DIR}/lib"
      SCRIPTS_LIB_DIR_FOUND=1
    fi
  fi
fi
REQUIRES_INSTALLING=0
if [[ ${SCRIPTS_LIB_DIR_FOUND} -eq 0 ]]; then
  if is_scripts_lib_dir "${BASE_INSTALL_DIR}"/lib; then
    SCRIPTS_LIB_DIR="${BASE_INSTALL_DIR}"/lib
    SCRIPTS_LIB_DIR_FOUND=1
  else
    REQUIRES_INSTALLING=1
  fi
fi
if [[ ${REQUIRES_INSTALLING} -eq 1 ]]; then
  if [[ -z ${AUTO_INSTALL} ]]; then
    echo "The shell-scripts library is not installed."
    echo "Please run the following command to install it:"
    echo "  curl -sL \"https://raw.githubusercontent.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/main/install.sh\" | bash"
    exit 1
  else
    echo "Installing shell-scripts library..."
    if ! curl -sL "https://raw.githubusercontent.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/main/install.sh" | bash; then
      echo "Failed to install shell-scripts library."
      exit 1
    fi
  fi
fi
