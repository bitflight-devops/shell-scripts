#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z "${SCRIPTS_LIB_DIR:-}" ]]; then
  LC_ALL=C
  export LC_ALL
  read -r -d '' GET_LIB_DIR_IN_ZSH <<- 'EOF'
	0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
	0="${${(M)0:#/*}:-$PWD/$0}"
	SCRIPTS_LIB_DIR="${0:a:h}"
	SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
	EOF
  # by using a HEREDOC, we are disabling shellcheck and shfmt
  read -r -d '' LOOKUP_SHELL_FUNCTION <<- 'EOF'
	lookup_shell() {
		export whichshell
		case $ZSH_VERSION in *.*) { whichshell=zsh;return;};;esac
		case $BASH_VERSION in *.*) { whichshell=bash;return;};;esac
		case "$VERSION" in *zsh*) { whichshell=zsh;return;};;esac
		case "$SH_VERSION" in *PD*) { whichshell=sh;return;};;esac
		case "$KSH_VERSION" in *PD*|*MIRBSD*) { whichshell=ksh;return;};;esac
	}
	EOF
  eval "${LOOKUP_SHELL_FUNCTION}"
  # shellcheck enable=all
  lookup_shell
  if command_exists zsh && [[ "${whichshell}" == "zsh" ]]; then
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
: "${SYSTEM_FUNCTIONS_LOADED:=1}"

get_iso_time() {
  date +%Y-%m-%dT%H:%M:%S%z
}

command_exists() {
  command -v "$@" > /dev/null 2>&1
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
  if [[ -f "${shell_rc}" ]]; then
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
  elif [[ "${save_var}" == "true" ]]; then
    local -r file="$(shell_rc_file)"

    if [[ -f "${file}" ]]; then
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
    error "Could not find a shell profile file to set the environment variable in."
    return 1
  fi
  if [[ ! -f ${file} ]]; then
    "${TOUCH[@]:-touch}" "${file}" || return 1
  fi
  #  /[.*+?^${}()|[\]\\]/g, '\\$&'
  if [[ "${name}" == "PATH" ]]; then
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
  if [[ $# -gt 0 ]] && ! isEmptyString "${updateInterval:-}"; then
    local updateInterval="${1:-}"
  else
    updateInterval="$((24 * 60 * 60))"
  fi

  if [[ ${lastAptGetUpdate} -gt ${updateInterval} ]]; then
    if command_exists apt-fast; then
      info "apt-fast update -qq"
      run_as_root apt-fast update -qq -m
    else
      info "apt-get update -qq"
      run_as_root apt-get update -qq -m
    fi
  else
    local lastUpdate="$(date -u -d @"${lastAptGetUpdate}" +'%-Hh %-Mm %-Ss')"

    info "\nSkip apt-get update because its last run was '${lastUpdate}' ago"
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

prefix_sudo() {
  if command_exists sudo && ! sudo -v > /dev/null 2>&1; then
    echo sudo
  fi
}

app_installer() (
  set +x
  if command_exists apt-fast; then
    runAptGetUpdate
    run_as_root apt-fast -y "$@"
  elif command_exists yum; then
    run_as_root yum -y -t "$@"
  elif command_exists apt-get; then
    runAptGetUpdate
    run_as_root apt-get -y "$@"
  elif command_exists brew; then
    brew "$@"
  else
    debug "Can't install: " "$@"
    return 1
  fi
)

installer() {
  app_installer "$@"
}

install_app() (
  set +x
  # Usage: install_app <app name> [second app] [third app]
  # Is App installed?
  INSTALL_LIST=("${@}")

  if [[ ${#INSTALL_LIST[@]} -gt 0 ]]; then
    if is_darwin; then
      app_installer install "${INSTALL_LIST[@]}"
    elif [[ "$(uname -s | cut -c1-5)" == "Linux" ]]; then
      app_installer install -y -qq "${INSTALL_LIST[@]}"
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
    if command_exists brew && in_brew ${brew_app_name}; then
      brew install ${brew_app_name} > /dev/null 2>&1 || true &
    elif [[ -n ${alternate_install_script_url-} ]]; then
      installer_file=$(mktemp -q -u -t installerXXXX)
      curl -fsSLl -o "${installer_file}" "${alternate_install_script_url}"
      if [[ "${#install_flags}" -gt 0 ]]; then
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
