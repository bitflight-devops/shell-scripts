#!/usr/bin/env bash

# Commands to start this datastore in the background
# Path: packages/kv-in-memory/backend/redis/start.sh
backend_name="redis-server"

kv_install_backend() {
  if is_darwin; then
    if [[ ! -x "$(command -v brew)" ]]; then
      info_log "Installing brew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    if [[ ! -x "$(command -v redis-server)" ]]; then
      info_log "Installing redis-server"
      brew install redis
    fi
  else
  if [[ ! -x "$(command -v redis-server)" ]]; then
    info_log "Installing redis-server"
    sudo apt-get install -y redis-server
  fi
}

kv_get() {
  local -r key="${1?Missing key argument}"
  local -r value="$(redis-cli get "${key}")"
  echo "${value}"
}

kv_set() {
  local -r key="${1?Missing key argument}"
  local -r value="${2?Missing value argument}"
  redis-cli set "${key}" "${value}"
}

kv_start() {
  local -r kv_backend_name="${1?Missing kv_backend_name argument}"
  local -r kv_backend_port="${2?Missing kv_backend_port argument}"
  local -r kv_backend_host="${3?Missing kv_backend_host argument}"
  local -r kv_backend_password="${4?Missing kv_backend_password argument}"
  local -r kv_backend_db="${5?Missing kv_backend_db argument}"

  local -r kv_backend_name_lower="$(echo "${kv_backend_name}" | tr '[:upper:]' '[:lower:]')"
  local -r kv_backend_port="${kv_backend_port:-6379}"
  local -r kv_backend_host="${kv_backend_host:-localhost}"
  local -r kv_backend_password="${kv_backend_password:-}"
  local -r kv_backend_db="${kv_backend_db:-0}"

  redis \
    --port "${kv_backend_port}" \
    --bind "${kv_backend_host}" \
    --requirepass "${kv_backend_password}" \
    --dbfilename "${kv_backend_name_lower}.rdb" \
    --dir "${kv_backend_name_lower}" \
    --daemonize yes \
    --save "" \
    --appendonly no \
    --appendfsync no \
    --databases "${kv_backend_db}" \
    --loglevel warning \
    --logfile "${kv_backend_name_lower}.log"

}
