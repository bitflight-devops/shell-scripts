#!/usr/bin/env bash
export SYSTEM_FUNCTIONS_LOADED=1
get_iso_time() {
  date +%Y-%m-%dT%H:%M:%S%z
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
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
    kill -0 "${PID}" >/dev/null 2>&1
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

set_env_var() {
  local name="${1//\s/}"
  local value="$2"
  local file
  local prefix=''
  [[ -z ${HOME-} ]] && export HOME="$(cd ~/ && pwd -P)"

  if [[ -n ${GITHUB_ACTIONS:+x} ]]; then
    file="${GITHUB_ENV}"
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

  if [[ -n ${value} ]]; then
    if [[ ${value} == "${HOME}"* ]]; then
      value="\$HOME${value#"${HOME}"}"
    fi
    if grep -q "^${prefix:-}${name}=" "${file}"; then
      # Handle Mac or Linux if available
      command_exists perl && perl -pi -e "s#^${prefix:-}${name}=.*#${prefix:-}${name}=${value}#g" "${file}" && return 0
      # Handle Linux
      command_exists sed && sed -i "s#^${prefix:-}${name}=.*#${prefix:-}${name}=${value}#g" "${file}" && return 0
    else
      echo "${prefix:-}${name}=${value}" >>"${file}" && return 0
    fi
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
  grep -q -v ":${item}:" <<<":${p#:}:"
}

add_to_path() {
  # if [[ -d "${1}" ]]; then
  if [[ -z ${PATH} ]]; then
    export PATH="${1}"
    running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
    debug "Path created: ${1}"
    set_env_var PATH "${1}:${PATH}"
  elif not_in_path "${1}"; then
    export PATH="${1}:${PATH}"
    running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
    debug "Path added: ${1}"
    set_env_var PATH "${1}:${PATH}"
  fi
  # fi
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
  local -r user="$(id -un 2>/dev/null || true)"
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
  if command_exists sudo && ! sudo -v >/dev/null 2>&1; then
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
