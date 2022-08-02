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

not_in_path() {
  tr ':' '\n' <<<"${PATH}" | grep -q -e "^$1$"
}
add_to_path() {
  # if [[ -d "${1}" ]]; then
    if [[ -z "${PATH}" ]]; then
      export PATH="${1}"
      running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
      debug "Path created: ${1}"
    elif not_in_path "${1}"; then
      export PATH="${1}:${PATH}"
      running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
      debug "Path added: ${1}"
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

prefix_sudo() {
  if command_exists sudo && ! sudo -v >/dev/null 2>&1; then
    echo sudo
  fi
}

app_installer() (
  set +x
  if command_exists apt-fast; then
    runAptGetUpdate
    run_as_root apt-fast -y "$@" --no-install-recommends
  elif command_exists yum; then
    run_as_root yum "$@"
  elif command_exists apt-get; then
    runAptGetUpdate
    run_as_root apt-get -y "$@" --no-install-recommends
  elif command_exists brew; then
    brew "$@"
  else
    debug "Can't install: " "$@"
    return 1
  fi
)

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