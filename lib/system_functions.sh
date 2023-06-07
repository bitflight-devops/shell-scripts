#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

# function_exists is a function to check if a function exists, faster than command_exists
function_exists() { declare -Ff -- "$@" > /dev/null; }
# command_exists is a function to check if a command exists, which is portable
command_exists() { command -v "$@" > /dev/null 2>&1; }

COMMAND_EXISTS_FUNCTION="$(declare -f command_exists)"
FUNCTION_EXISTS_FUNCTION="$(declare -f function_exists)"

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
: "${SYSTEM_FUNCTIONS_LOADED:=1}"

# Either returns bash or zsh
current_shell_type() {
  \shopt -u lastpipe > /dev/null 2>&1
  shell_name='bash'
  : | shell_name='zsh'
  echo "${shell_name}"
}
shell_major_version() {
  shell_name="$(current_shell_type)"
  case "${shell_name}" in
    bash)
      echo "${BASH_VERSINFO[0]}"
      ;;
    zsh)
      echo "${ZSH_VERSION%%.*}"
      ;;
    *)
      echo "Unknown shell type: ${0}"
      ;;
  esac
}
shell_minor_version() {
  shell_name="$(current_shell_type)"
  case "${shell_name}" in
    bash)
      echo "${BASH_VERSINFO[1]}"
      ;;
    zsh)
      echo "${ZSH_VERSION#*.}"
      ;;
    *)
      echo "Unknown shell type: ${0}"
      ;;
  esac
}
current_shell_version() {
  shell_name="$(current_shell_type)"
  case "${shell_name}" in
    bash)
      echo "${BASH_VERSION}"
      ;;
    zsh)
      echo "${ZSH_VERSION}"
      ;;
    *)
      echo "Unknown shell type: ${0}"
      ;;
  esac
}

get_iso_time() {
  date +%Y-%m-%dT%H:%M:%S%z
}

is_darwin() {
  case "$(uname -s)" in
    *darwin*) true ;;
    *Darwin*) true ;;
    *) false ;;
  esac
}

is_wsl() {
  case "$(uname -r)" in
    *microsoft*) true ;; # WSL 2
    *Microsoft*) true ;; # WSL 1
    *) false ;;
  esac
}

has_apt_package_manager() {
  ! is_darwin && command_exists apt-get
}

get_distribution() {
  local lsb_dist=""
  # Every system that we officially support has /etc/os-release
  if [[ -r /etc/os-release ]]; then
    lsb_dist="$(. /etc/os-release && echo "${ID}")"
  fi
  # Returning an empty string here should be alright since the
  # case statements don't act unless you provide an actual value
  echo "${lsb_dist}"
}

process_is_running() {
  PID="$1"
  if [[ -n ${PID:-} ]]; then
    kill -0 "${PID}" > /dev/null 2>&1
    return $?
  fi
  printf "%s(): No PID provided" "${0}"
  return 1
}

shell_rc_file() {
  [[ -z ${HOME-} ]] && export HOME="$(cd ~/ && pwd -P)"
  case "${SHELL}" in
    */bash*)
      shell_rc="${HOME}/.bashrc"
      ;;
    */zsh*)
      shell_rc="${HOME}/.zshrc"
      ;;
    *)
      shell_rc="${HOME}/.profile"
      export ENV=~/.profile
      ;;
  esac
  echo "${shell_rc}"
}

sed_inplace() {
  if grep -q "GNU sed" <<< "$(sed --version 2> /dev/null || true)"; then
    sed -i"" "$@" || true
  else
    sed -i "" "$@" || true
  fi
}

save_env_var() {
  local -r var_name="$1"
  local -r var_value="${2}" # "$(printf '%q' "${2}")"
  local -r shell_rc="$(shell_rc_file)"
  if [[ -f ${shell_rc}   ]]; then
    if grep -q "${var_name}" "${shell_rc}"; then
      sed_inplace "s|${var_name}=.*|${var_name}=${var_value}|" "${shell_rc}"
    else
      echo "${var_name}=${var_value}" >> "${shell_rc}"
    fi
  else
    echo "${var_name}=${var_value}" > "${shell_rc}"
  fi
}

append_path_var() {
  # This can be run alone, or eval'd to update the current shell
  # USAGE: to save to file and update local shell:
  # eval "export $(append_path_var true /path/to/dir)"
  # USAGE: to save to file only:
  # append_path_var save /path/to/dir
  # USAGE: to update local shell only:
  # eval "export $(append_path_var false /path/to/dir)"

  local -r var_name="PATH"
  local -r save_var="${1}"
  local -r new_path="PATH=${2}:\${PATH}"
  if running_in_github_actions; then
    # In GITHUB Actions, we can't write to the shell_rc_file
      local -r file="${GITHUB_PATH}"
      echo "${2}" >> "${file}"
  elif [[ ${save_var} == "true"   ]]; then
    local -r file="$(shell_rc_file)"

    if [[ -f ${file}   ]]; then
      if grep -q "${new_path}" "${file}"; then
        # Path already exists in file
        return
      fi
    fi
    # Path does not exist in file, so add it
    touch "${file}"
    printf '%s\n' "${new_path}" >> "${file}"
    # Var was saved
  fi
    # update local shell
    export PATH="${2}:${PATH}"

}
set_env_var() {
  local name="${1//\s/}"
  local value="$2"
  local file
  local prefix=''
  [[ -z ${HOME-} ]] && export HOME="$(cd ~/ && pwd -P)"

  if running_in_github_actions; then
    if [[ ${name} == "PATH" ]]; then
      file="${GITHUB_PATH}"
    else
      file="${GITHUB_ENV}"
    fi
  else
    file="$(shell_rc_file)"
    prefix='export '
  fi
  if [[ -z ${file:-} ]]; then
    error_log "Could not find a shell profile file to set the environment variable in."
    return 1
  fi
  if [[ ! -f ${file} ]]; then
    "${TOUCH[@]:-touch}" "${file}" || return 1
  fi
  #  /[.*+?^${}()|[\]\\]/g, '\\$&'
  if [[ ${name} == "PATH"   ]]; then
    # we adding a new path variable, so just add a new line
    eval "export $(append_path_var "true" "${value}")"
    return
  elif [[ -n ${value} ]]; then
    if [[ ${value} == "${HOME}"* ]]; then
      value="\${HOME}${value#"${HOME}"}"
    fi
    save_env_var "${name}" "${value}"
  else
    # Handle Mac or Linux if available
    command_exists perl && perl -pi -e "/^${name}=.*/d" "${file}" && return 0
    # Handle Linux
    command_exists sed && sed -i "/^${name}=.*/d" "${file}" && return 0
  fi
  return 1
}

not_in_path() {
  local -r item="$(trim "${1}")"
  local p="${PATH%:}"
  grep -q -v ":${item}:" <<< ":${p#:}:"
}

add_to_path() {
  append_path_var "${2:-"false"}" "${1}"
}

getLastAptGetUpdate() {
  local aptDate="$(stat -c %Y '/var/cache/apt')"
  local nowDate="$(date +'%s')"

  printf "%d" "$((nowDate - aptDate))"
}

runAptGetUpdate() (
  set +x
  local lastAptGetUpdate="$(getLastAptGetUpdate)"
  if [[ $# -gt 0 ]] && [[ -z ${updateInterval:-} ]]; then
    local updateInterval="${1:-}"
  else
    updateInterval="$((24 * 60 * 60))"
  fi

  if [[ ${lastAptGetUpdate} -gt ${updateInterval} ]]; then
    if command_exists apt-fast; then
      debug "apt-fast update -qq"
      run_as_root apt-fast update -qq -m
    else
      debug "apt-get update -qq"
      run_as_root apt-get update -qq -m
    fi
  else
    local lastUpdate="$(date -u -d @"${lastAptGetUpdate}" +'%-Hh %-Mm %-Ss')"

    info_log "Skip apt-get update because its last run was '${lastUpdate}' ago"
  fi
)

root_available() {
  local -r user="$(id -un 2> /dev/null || true)"
  if [[ ${user} != 'root' ]]; then
    if command_exists sudo; then
      local bin_false="/bin/false"
      uname | grep -q -i 'darwin' && bin_false="/usr/bin/false"
      if [[ $(SUDO_ASKPASS="${bin_false}" sudo -A sh -c 'whoami;whoami' 2>&1 | wc -l) -eq 2 ]]; then
        echo "sudo"
        return 0
      elif groups "${user}" | grep -q '(^|\b)(sudo|wheel)(\b|$)' && [[ -n ${INTERACTIVE:-} ]]; then
        echo "sudo"
        return 0
      else
        echo ""
        return 1
      fi
    else
      # not root, and don't have sudo
      echo ""
      return 1
    fi
  else
    echo ""
    return 0
  fi
}

# Return 0 if the current user has passwordless sudo access.
# Return 1 otherwise.
# This function is used to determine whether we need to use sudo commands
# when running commands that require root privileges.
has_passwordless_sudo_access() {
  # If we are already root, then we have passwordless sudo access.
  local whoami="$(whoami)"
  if [[ ${whoami} == "root" ]]; then
    return 0
  fi
  # If the SUDO_USER variable is set, then we have passwordless sudo access.
  # This variable is set by sudo when running commands with sudo.
  if [[ -n ${SUDO_USER:-} ]]; then
    return 0
  fi
  # If the SUDO_UID variable is set, then we have passwordless sudo access.
  # This variable is set by sudo when running commands with sudo.
  if [[ -n ${SUDO_UID:-} ]]; then
    return 0
  fi
  # If the SUDO_GID variable is set, then we have passwordless sudo access.
  # This variable is set by sudo when running commands with sudo.
  if [[ -n ${SUDO_GID:-} ]]; then
    return 0
  fi
  # If the SUDO_ASKPASS variable is set to /bin/false, then we do not have
  # passwordless sudo access.  We set this variable to /bin/false and then
  # attempt to run the whoami command with sudo, which will prompt for a
  # password.  If the whoami command returns successfully, then we have
  # passwordless sudo access.  Otherwise, we do not.
  SUDO_ASKPASS="/bin/false" sudo -A whoami > /dev/null 2>&1
}

prefix_sudo() {
  if command_exists sudo && ! sudo -v > /dev/null 2>&1; then
    echo sudo
  fi
}

formula_in_directory() {
  command_exists brew || return 1
  local directory="$1"
  local formula="$2"

  local exact="${3:-true}"

  if [[ ${exact:-} == "true"   ]]; then
    [[ -e "${directory}/${formula}" ]]
  else
    [[ -e "${directory}/${formula}" ]] || grep -q -i -E '\b'"${formula:?}"'-?.*(\b|$|,)' <<< "$(ls -m "${directory}")"
  fi
}
formula_in_brew_opt() {
  command_exists brew || return 1
  local -r formula="$1"
  local -r opt="$(brew --prefix)/opt"
  formula_in_directory "${opt}" "${formula}" "${2:-true}"
}

# Checks if a given Homebrew formula exists.
# Usage: brew_formula_installed <formula>
# Returns: 0 if the formula exists, 1 otherwise
brew_formula_installed() {
  local formula="$1"
  local formula_file="$(HOMEBREW_NO_INSTALL_FROM_API=1 brew formula "${formula}")"
  [[ ${formula_file} == */*.rb ]] && HOMEBREW_NO_INSTALL_FROM_API=1 brew ls --versions "${formula}" > /dev/null 2>&1
}

# If brew has the formula passed as an argument, upgrade it; otherwise, install it.
brewInstall() {
  if brew_formula_installed "$1" && [[ -n ${UPGRADE_PACKAGES:-}   ]]; then
    HOMEBREW_NO_INSTALL_FROM_API=1 NONINTERACTIVE=1 brew upgrade "$1" || true > /dev/null
  else
    HOMEBREW_NO_INSTALL_FROM_API=1 NONINTERACTIVE=1 brew install "$1" || true > /dev/null
  fi
}

ubuntu_package_installed() {
  if command_exists dpkg-query; then
    dpkg-query -W "${1}" > /dev/null 2>&1
  else
    error_log "dpkg-query not found, checking for ${*} failed"
    return 1
  fi
}
yum_package_installed() {
  if command_exists rpm; then
    rpm -q "${1}" > /dev/null 2>&1
  elif command_exists yum; then
    yum list installed "${1}" > /dev/null 2>&1
  else
    error_log "rpm, yum not found, checking for ${*} failed"
    return 1
  fi
}
pip_package_installed() {
  if command_exists pip3; then
    pip3 show "${1}" > /dev/null 2>&1
  else
    error_log "pip not found, checking for ${*} failed"
    return 1
  fi
}

# This function takes a Python binary name as an argument and outputs the
# version of the binary as a number. If the binary is not found, it outputs 0.
# Example: get_python_version_as_integer("python3") -> 306

get_python_version_as_integer() {
  local version
  local python_bin="${1:-python3}"
  if command_exists "${python_bin}"; then
    version="$("${python_bin}" -c 'import sys; print(sys.version_info[0]*100 + sys.version_info[1])')"
  else
    version=0
  fi
  echo "${version}"
}

install_python3_suite() {
  declare -a MISSING_APPS
  if ! command_exists python3; then
    MISSING_APPS+=("python3")
  fi
  if ! command_exists pip3; then
      MISSING_APPS+=("python3-pip")
  fi
  if ! command_exists virtualenv; then
      MISSING_APPS+=("python3-venv")
  fi
  if ! squash_output pip_package_installed setuptools; then
      MISSING_APPS+=("python3-setuptools")
  fi
  if ! squash_output pip_package_installed wheel; then
      MISSING_APPS+=("python3-wheel")
  fi
  if [[ ${#MISSING_APPS[@]} -ne 0   ]]; then
    { ! is_darwin && command_exists apt-get && squash_output install_apt-fast; } || true
    install_app "${MISSING_APPS[@]}" || true
  fi

  if ! command_exists pipx; then
    python3 -m pip install -U --quiet pipx || true
    squash_output python3 -m pipx ensurepath
  fi
  add_to_path "${HOME}/.local/bin"
}

dircolors() {
  if command_exists vivid; then
    if [[ ${#} -eq 0 ]]; then
      command vivid generate molokai
    else
      command vivid "$@"
    fi
  else
    if [[ ${#} -eq 0 ]]; then
      if command_exists gdircolors; then
        command gdircolors -b
      elif command_exists dircolors; then
        command dircolors -b
      fi
    else
      if command_exists gdircolors; then
        command gdircolors "$@"
      elif command_exists dircolors; then
        command dircolors "$@"
      fi
    fi
  fi
}

find_file_under_directory() {
  local directory="$1"
  shift
  local file="$1"
  shift
  local depth="${1:-1}"
  shift

  if command_exists fd; then

    local flags=("--type" "f" "--ignore-case" "--hidden" "--follow" --max-depth "${depth}")
    if [[ -n ${1:-}   ]]; then
      flags+=("${@}")
    fi

    fd "${flags[@]}" \
      --exclude .git \
      --exclude .svn \
      --exclude .hg \
      --exclude .bzr \
      --exclude .DS_Store \
      "${file}" \
      "${directory}"
  elif command_exists find; then
    # "-print" "-quit"
    local flags=("-type" "f" "-iregex" ".*${file}" -depth "${depth:-1}")
    if [[ -n ${1:-}   ]]; then
      flags+=("${@}")
    fi
    find "${directory}" "${flags[@]}"
  elif [[ -f "${directory}/${file}" ]]; then
    echo "${directory}/${file}"
  fi
}

mpm_configuration_file_path() {
  local file_regex='*.(toml|yaml|yml|json|ini|xml)'
  local config_dir
  if is_darwin; then
    config_dir="${HOME}/Library/Application Support/mpm/"
  else
    config_dir="${HOME}/.config/mpm/"
  fi
  file_list=$(find_file_under_directory "${config_dir}" "${file_regex}")
  if [[ $(wc -l <<< "${file_list}" | tr -d ' ') -gt 1 ]]; then
    error_log "Multiple mpm configuration files found in ${config_dir}"
    error_log "Please remove all but one of the following files:"
    error_log "${file_list}"
    return 1
  fi
  config_file=$(head -1 <<< "${file_list}")
  if [[ -z ${config_file}   ]]; then
    config_file="${config_dir}/mpm.toml"
    touch "${config_file}"
  fi
  echo "${config_file}"
}

configure_meta_package_manager() {
  config_file="$(mpm_configuration_file_path)"

  info_log "configure_meta_package_manager: command not completed"
}

install_meta_package_manager() {
  install_python3_suite
  if command_exists mpm; then
    version=$(mpm --version | head -1 | cut -d' ' -f3 | tr -d '.')
    if [[ ${version} -lt 5120   ]]; then
      squash_output pipx upgrade meta-package-manager || true 2> /dev/null
    fi
  fi
  squash_output pipx install meta-package-manager
  # configure_meta_package_manager
}

package_manager() {

  if command_exists apt; then
    runAptGetUpdate 2> /dev/null
  fi
  if command_exists brew; then
    HOMEBREW_NO_INSTALL_FROM_API=1 NONINTERACTIVE=1 brew "$@"
  elif command_exists apt-fast; then
    DEBIAN_FRONTEND=noninteractive run_as_root apt-fast -y -qq "$@"
  elif command_exists yum; then
    run_as_root yum -y -qq -t "$@"
  elif command_exists apt-get; then
    DEBIAN_FRONTEND=noninteractive run_as_root apt-get -y -qq "$@"
  else
    if ! command_exists mpm && [[ ! -f "${HOME}/.installing-meta-package-manager" ]]; then
      touch "${HOME}/.installing-meta-package-manager"
      install_meta_package_manager
    fi
    if command_exists mpm; then
      if is_darwin || command_exists brew; then
        mpm -m brew -m cargo -m pip -m npm --continue-on-error --time -v CRITICAL "${@}"
      else
        DEBIAN_FRONTEND=noninteractive run_as_root mpm  --continue-on-error --time -v CRITICAL "${@}"
      fi
    else
      error_log "No package manager found"
      return 1
    fi
  fi
}

installer() {
  package_manager "$@"
}

install_app() (
  set +x
  # Usage: install_app <app name> [second app] [third app]
  # Is App installed?
  INSTALL_LIST=("${@}")

  if [[ ${#INSTALL_LIST[@]} -gt 0 ]]; then
    if is_darwin; then
      package_manager install "${INSTALL_LIST[@]}"
    elif [[ "$(uname -s | cut -c1-5)" == "Linux" ]]; then
      package_manager install "${INSTALL_LIST[@]}"
    fi
  fi
)

in_brew() {
  NONINTERACTIVE=1 HOMEBREW_NO_ANALYTICS=1 brew info -q --json --formula "$@" > /dev/null 2>&1
}

install_if_missing() {
  cli_command="$1"
  shift
  brew_app_name="$1"
  shift
  alternate_install_script_url="$1"
  shift
  install_flags=("$@")
  if ! command_exists "${cli_command}"; then
    if command_exists brew && in_brew "${brew_app_name}"; then
      brew install "${brew_app_name}" > /dev/null 2>&1 || true &
    elif [[ -n ${alternate_install_script_url-} ]]; then
      installer_file=$(mktemp -q -u -t installerXXXX)
      curl -fsSLl -o "${installer_file}" "${alternate_install_script_url}"
      if [[ ${#install_flags} -gt 0   ]]; then
        chmod +x "${installer_file}" \
                                     && NONINTERACTIVE=1 "${installer_file}" "${install_flags[@]}"
      else
        NONINTERACTIVE=1 source <(curl -Ls "${alternate_install_script_url}")
      fi
    else
      echo "$0: Could not install ${cli_command} because it is not available via brew and no alternate install script was provided."
    fi
  fi
}
