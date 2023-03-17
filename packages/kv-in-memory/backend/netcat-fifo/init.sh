#!/usr/bin/env bash

get_git_root() { git -C "${1:-${PWD}}" rev-parse --show-toplevel 2> /dev/null; }
if [[ ! -n ${SCRIPTS_LIB_DIR:-} ]]; then
  PACKAGES_APP_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)" \
    && SCRIPTS_LIB_DIR="$(get_git_root "${PACKAGES_APP_DIR}" || { cd "${PACKAGES_APP_DIR}/../.." && pwd -P; })/lib"
fi
if [[ ! -d ${SCRIPTS_LIB_DIR:-} ]]; then
  echo "SCRIPTS_LIB_DIR(${SCRIPTS_LIB_DIR:-}) is not a directory" >&2
  exit 1
fi
if [[ ! -f ${SCRIPTS_LIB_DIR}/bootstrap.sh ]]; then
  echo "SCRIPTS_LIB_DIR/bootstrap.sh (${SCRIPTS_LIB_DIR:-}/bootstrap.sh) is not a file" >&2
  exit 1
fi
[[ -z ${SHELL_SCRIPTS_BOOTSTRAP_LOADED:-} ]] && SHELL_SCRIPTS_QUIET=1 source "${SCRIPTS_LIB_DIR}/bootstrap.sh"

# This file is part of the kv-in-memory package.

# Goal is to star a KV in memory server, for storing
# environment variables, and other data that doesn't
# need to be persisted, but also doesn't need to be
# updated often. Such as which installer to use, or
# which version of a package to use.

# | Argument | Description | Default | Required |
# |----------|-------------|---------|----------|
# | -p       | Port        | 63791   | No       |
export LISTENPORT=${1:-63791}
export fifo_ref="${RANDOM}.fifo"
export running_lock="${RANDOM}.run"
# shellcheck disable=SC1091
declare -A KV_SERVICE_AVAILABILITY=()

# Check if we have <x> installed and running
is_available() {
  local service="${1?Missing service argument}"
  service="$(lowercase "${service}")"
  if [[ ${KV_SERVICE_AVAILABILITY["${service}"]:-} == "true" ]]; then
    return 0
  elif [[ ${KV_SERVICE_AVAILABILITY["${service}"]:-} == "false" ]]; then
    return 1
  fi

  case "${service}" in
    "docker_host")

      if is_darwin; then
        if docker ps 2> /dev/null | grep -q "CONTAINER ID"; then
          return 0
        else
          return 1
        fi
      else
        if systemctl status docker 2> /dev/null | grep -q "Active: active (running)"; then
          return 0
        else
          return 1
        fi
      fi
      ;;
    "redis_service")
      echo "item = 2 or item = 3"
      ;;
    *)
      echo "default (none of above)"
      ;;
  esac

}

port_available_lsof() {
  local port="${1?Missing port argument}"
  if [[ -z ${port} ]]; then
    return 1
  fi
  if [[ ${port} -lt 1 ]] || [[ ${port} -gt 65535 ]]; then
    return 1
  fi
  if [[ $(lsof -i -P -n | grep LISTEN | grep -c ":${port}") -gt 0 ]]; then
    return 1
  fi
  return 0
}

port_available_sockets() {
  local ip="${1?Missing ip argument}"
  local port="${2?Missing port argument}"
  if [[ -z ${port} ]]; then
    return 1
  fi
  if [[ ${port} -lt 1 ]] || [[ ${port} -gt 65535 ]]; then
    return 1
  fi
  if ${IN_BASH:-false}; then
    if printf "" 2>> /dev/null >> "/dev/tcp/${ip}/${port}"; then
      echo "${port} available"
      return 0
    fi
  else
    bash -c 'printf "" 2>>/dev/null >>"/dev/tcp/${0}/${1}"' "${ip}" "${port}"
    echo "${port} available via subshell"
    return 0
  fi
  echo "${port} not available"
  return 1
}
kill_port() {
  local port="${1?Missing port argument}"
  if [[ -z ${port} ]]; then
    return 1
  fi
  echo "Killing off process on port ${port}"
  kill "$(lsof -i ":${port}" | tail -1 | awk '{print $2}')"
}

ephemeral_port() {
    local LOW_BOUND=49152
    local RANGE=16384
    local ip="${1:-127.0.0.1}"
    while true; do
        local candidate_port=$((LOW_BOUND + (RANDOM % RANGE)))
        # (echo "" >"/dev/tcp/127.0.0.1/${CANDIDATE}") >/dev/null 2>&1
        # printf "" 2>>/dev/null >>/dev/tcp/"${ip}"/"${candidate_port}"
        if port_available_sockets "${ip}" "${candidate_port}"; then
            echo "${CANDIDATE}"
            break
    fi
  done
}

__handle_fifo_data() {
  local key
  local value
  local line
  while [[ -e "$1" ]]; do
    while read -r line; do
      echo "__handle_fifo_data: received line: ${line}" >&2
      line=$(trim "${line}")
      IFS="=" read -r key value <<< "${line}"
      echo "__handle_fifo_data: received kv: ${key}=${value}" >&2
      case "${key}" in
        "__GET__"*)
          local response_port="${key:8}"
          local key="${value}"
          local value="${KV["${key}"]}"
          echo "__handle_fifo_data: responding to get with: ${key}=${value}" >&2
          echo "${key}=${value}"
          break
          ;;
        *"__EXIT__"*)
          echo "exiting" >&2
          exit 0
          ;;
        *"__PING__"*)
          echo "pinging" >&2
          echo "pong"
          break
          ;;

        *)
          echo "__handle_fifo_data: setting: ${key}=${value}" >&2
          KV["${key}"]="${value}"
          ;;
      esac
      echo "__handle_fifo_data: done with line: ${line}" >&2
    done < "$1"
  done
}

__feed_fifo() {
  # This is important, otherwise we'll trash the terminal with lots of
  # bash pids trying to read a dead stdin
  while [[ -e "$1" ]]; do
      # Testing again in case of concurrency
      [[ -e "$1" ]] && cat - > "$1"
  done
}

# Cleaning up if something goes south or the program simply ends
trap 'rm -rf ${fifo_ref} ${running_lock}' EXIT INT TERM HUP

kv_subprocess() {
  # Let's get this party started
  touch "${running_lock}"
  declare -A KV=()
  export KV
  # Won't stop until you say so
  while [[ -e "${running_lock}" ]]; do
    # Let's clear out the fifo so we don't get dirt from previous connections
    [[ -e "${fifo_ref}" ]] && rm -rf "${fifo_ref}"
    mkfifo "${fifo_ref}"
    echo "kv_subprocess: KV -- " "${KV[@]}" >&2
    # Netcat port listenport
    # We'll feed the nc using our __handle_fifo_data and read from it to a
    # __feed_fifo which will try to keep stdin open all the time, feeding
    # __handle_fifo_data
    nc -l "${LISTENPORT}" \
      0< <(  __handle_fifo_data "${fifo_ref}") \
      1> >(  __feed_fifo "${fifo_ref}")
  done
}

if command_exists nc; then
  kv_get() {
    local key="${1?Missing key argument}"
    local value
    info_log "getting value for key ${key}" >&2
    nc -c -n "127.0.0.1" "${LISTENPORT}" <<< "__GET__=${key}"
    info_log "got value ${value} for key ${key}" >&2
  }
  kv_set() {
    local key="${1?Missing key argument}"
    local value="${2?Missing value argument}"
    info_log "kv_set: setting value for key ${key}" >&2
    nc -w 1 -c -n "127.0.0.1" "${LISTENPORT}" <<< "${key}=${value}"
    info_log "kv_set: set value for key ${key}" >&2
  }

  # kv_subprocess() {
  #   declare -A PAIRS=(["__EXIT__"]="false")
  #   local key
  #   local value
  #   while true; do
  #     if [[ "${PAIRS["__EXIT__"]}" != "false" ]]; then
  #       info_log "exiting main loop"
  #       break
  #     fi
  #     info_log "waiting for request"
  #     while IFS="=" read -r key value; do
  #       if [[ "${key}" == "__EXIT__" ]] || [[ -n ${PAIRS["__EXIT__"]+x} ]]; then
  #         PAIRS["__EXIT__"]="true"
  #         info_log "exiting"
  #         break
  #       fi
  #       if [[ ${key} == "__GET__"* ]]; then
  #         local response_port="${key#__GET__}"
  #         log_info "responding on port ${response_port}"
  #         nc -w 1 -c -n "127.0.0.1" "${response_port}" <<< "${key}=${value}"
  #         info_log "Got value:" "${PAIRS["${value}"]}"
  #       else
  #         PAIRS["${key}"]="${value}"
  #         info_log "set ${key} to ${value}"
  #       fi
  #     done < <(nc -c -l "${LISTENPORT}")
  #   done
  # }
  port_available_sockets "127.0.0.1" "${LISTENPORT}" || kill_port "${LISTENPORT}"
  kv_subprocess &
  export kv_subprocess_pid=$!

  cleanup_kv_process() {
    info_log "Cleaning up kv subprocess ${kv_subprocess_pid}"
    kill "${kv_subprocess_pid}"
    rm -rf "${fifo_ref}"
    rm -rf "${running_lock}"
  }

  trap cleanup_kv_process EXIT
  export -f port_available_sockets
  export -f port_available_lsof
  export LISTENPORT
  # hyperfine -i 'port_available_sockets "127.0.0.1" "${LISTENPORT}"' 'port_available_lsof "${LISTENPORT}"'
  echo "KV in memory server started on port ${LISTENPORT}"
  # nc 127.0.0.1 "${LISTENPORT}" <<<"__PING__"
  kv_set jamie nelson
  kv_set jemma field
  kv_get jamie
  kv_get jemma
  kv_set "__EXIT__" "true"

fi
if is_available "docker_host"; then
  echo "Docker is available"
else
  echo "Docker is not available"
fi
