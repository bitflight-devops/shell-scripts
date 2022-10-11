#!/usr/bin/env bash
# Current Script Directory
if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi
if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
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
export REMOTE_UTILITY_FUNCTIONS_LOADED=1
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"

#########################
# FILE REMOTE UTILITIES #
#########################
# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
# Successive backoffs double the timeout.
withBackoff() {
  local max_attempts=${ATTEMPTS:-5}
  local timeout=${TIMEOUT:-1}
  local attempt=1
  local exitCode=0

  while ((attempt < max_attempts)); do
    if "$@"; then
      return 0
    else
      exitCode=$?
    fi

    warning "Failure! Retrying in ${timeout}.."
    sleep "${timeout}"
    attempt=$((attempt + 1))
    timeout=$((timeout * 2))
  done

  if [[ ${exitCode} -gt 0 ]]; then
    error "${0}(): All Attempts Failed! ($*)"
  fi

  return "${exitCode}"
}

checkExistURL() {
  local -r url="${1}"
  if grep -q 'X-Amz-Credential' <<<"${url}"; then
    warning "Skipping checkExistURL for ${url}, it is a presigned URL"
    return 0
  fi
  if [[ "$(existURL "${url}")" == 'false' ]]; then
    fatal "${0}(): url '${url}' not found"
  fi
}

##
## CURL_DISABLE_ETAG_DOWNLOAD=true to disable etag download and comparison
downloadFile() {
  set -e
  local -r url="${1}"
  local -r destinationFile="${2:--}"
  local overwrite="${3:-true}"

  checkExistURL "${url}"

  # Check Overwrite
  isBoolean "${overwrite}" || fatal "${0}(): 'overwrite' must be a boolean"

  # Validate
  if [[ ${destinationFile} != "-" ]]; then
    if [[ -f ${destinationFile} ]]; then
      if isFalse "${overwrite}"; then
        fatal "${0}(): file '${destinationFile}' found"
      fi
      rm -f "${destinationFile}"
    elif [[ -e ${destinationFile} ]]; then
      fatal "${0}(): file '${destinationFile}' already exists"
    fi

    # Download
    dirPath="$(dirname "${destinationFile}")"
    fileName="$(basename "${destinationFile}")"
    debug "\nDownloading '${url}' to '${destinationFile}'\n"
  else
    local TO_STD_OUT=true
  fi
  if command_exists wget; then
    DOWNLOAD_ARGS=(--timestamping -q --no-dns-cache --no-hsts)
    DOWNLOAD_ARGS+=(--no-http-keep-alive --compression=auto --continue)
    DOWNLOAD_ARGS+=(--dns-timeout=3 --waitretry=2 --tries=2)
    DOWNLOAD_ARGS+=(--connect-timeout=30 --xattr)
    if [[ -z ${TO_STD_OUT:-} ]] && [[ ${overwrite} == 'false' ]]; then
      DOWNLOAD_ARGS+=(--no-clobber)
    fi
    withBackoff wget -q -O "${destinationFile}" "${url}" "${DOWNLOAD_ARGS[@]}"
  elif command_exists curl || installCURLCommand >/dev/null 2>&1; then
    DOWNLOAD_ARGS=(--create-dirs)
    DOWNLOAD_ARGS+=(--fail --remote-time --compressed)
    if [[ -z ${TO_STD_OUT} ]] && [[ -f ${destinationFile:-} ]]; then
      lastDownloadedModifiedDate=$(stat -c '%y' "${destinationFile}")
      lastModifiedDate=$(TZ=GMT date -d "${lastDownloadedModifiedDate}" '+%a, %d %b %Y %T %Z')
      DOWNLOAD_ARGS+=(--header="If-Modified-Since: ${lastModifiedDate}")
      if isFalse "${CURL_DISABLE_ETAG_DOWNLOAD}"; then
        etagPath="/usr/local/etc/etags/${dirPath}/"
        mkdir -p "${etagPath}"
        etagFile="${etagPath}/.etag.${fileName//[^a-zA-Z0-9]/_}"
        DOWNLOAD_ARGS+=(--etag-save="${etagFile}" --etag-compare="${etagFile}")
      fi
    fi
    withBackoff curl -sSL -o "${destinationFile}" "${url}" "${DOWNLOAD_ARGS[@]//=/ }"
  else
    fatal "${0}(): wget or curl not found"
  fi
}

app_installed() {
  local -r app="${1}"
  if command_exists apt-cache && apt-cache policy "${app}" | grep -q -v 'Unable to locate package'; then
    return 1
  elif command_exists yum && ! yum list installed "${app}" >/dev/null 2>&1; then
    return 1
  elif command_exists brew && ! brew list "${app}" >/dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

installCURLCommand() {
  APPS_TO_INSTALL=()
  if ! app_installed "ca-certificates"; then
    APPS_TO_INSTALL+=("ca-certificates")
  fi
  if ! command_exists curl; then
    APPS_TO_INSTALL+=("curl")
  fi
  if [[ ${#APPS_TO_INSTALL[@]} -gt 0 ]]; then
    install_app "${APPS_TO_INSTALL[@]}"
  fi
}

existURL() {
  local -r url="${1}"
  # Install Curl
  installCURLCommand >'/dev/null'
  # Check URL
  if (curl -f --head -L "${url}" -o '/dev/null' -s ||
    curl -f -L "${url}" -o '/dev/null' -r 0-0 -s); then
    echo 'true' && return 0
  fi
  echo 'false' && return 1
}

getRemoteFileContent() {
  local -r url="${1}"
  checkExistURL "${url}"
  curl -s -X 'GET' -L "${url}"
}

basic_wget() {
  # shellcheck disable=SC2034
  IFS=/ read -r proto z host query <<<"$1"
  exec 3<"/dev/tcp/${host}/80"
  {
    echo "GET /${query} HTTP/1.1"
    echo "connection: close"
    echo "user-agent: wget"

    echo "host: ${host}"
    echo "accept: */*"
    echo
  } >&3
  sed '1,/^$/d;s/<[^>]*>/ /g;' <&3 >"$(basename "$1")"
}

configure_bastion_ssh_tunnel() {
  if [[ -z ${BASTION_HOST} ]] || [[ -z ${BASTION_USER} ]] || [[ -z ${BASTION_PRIVATE_KEY} ]]; then
    error "One or more essential bastion variables missing: BASTION_PRIVATE_KEY:'${BASTION_PRIVATE_KEY:0:10}' BASTION_HOST:'${BASTION_HOST}' BASTION_USER:'${BASTION_USER}'"
    exit 1
  fi
  mkdir -p ~/.ssh
  if [[ ! -f "${HOME}/.ssh/config" ]]; then
    touch "${HOME}/.ssh/config"
  fi
  if ! grep -q "remotehost-proxy" "${HOME}/.ssh/config"; then
    cat <<EOF >>"${HOME}/.ssh/config"
Host remotehost-proxy
    HostName ${BASTION_HOST}
    User ${BASTION_USER}
    IdentityFile ~/.ssh/bastion.pem
    ControlPath ~/.ssh/remotehost-proxy.ctl
    ForwardAgent yes
    TCPKeepAlive yes
    ConnectTimeout 5
    ServerAliveInterval 60
    ServerAliveCountMax 30

EOF
  fi
  # ControlPath ~/.ssh/remotehost-proxy.ctl
  touch ~/.ssh/known_hosts
  rm -f ~/.ssh/bastion.pem
  echo "${BASTION_PRIVATE_KEY}" | base64 -d >~/.ssh/bastion.pem
  chmod 700 ~/.ssh || true
  chmod 600 ~/.ssh/bastion.pem || true
  if ! grep -q "${BASTION_HOST}" ~/.ssh/known_hosts; then
    ssh-keyscan -T 15 -t rsa "${BASTION_HOST}" >>~/.ssh/known_hosts || true
  fi

}

check_ssh_tunnel() {
  ssh -O check remotehost-proxy >/dev/null 2>&1
}

open_bastion_ssh_tunnel() {
  if ! check_ssh_tunnel; then
    ssh -4 -f -T -M -L"${BINDHOST:-127.0.0.1}:${JDBC_LOCAL_PORT:-${JDBC_PORT:-3306}}:${JDBC_HOST}:${JDBC_PORT:-3306}" -N remotehost-proxy && echo "SSH tunnel connected"
  else
    echo "SSH tunnel already connected"
  fi
}

close_bastion_ssh_tunnel() {
  if [[ -f "${HOME}/.ssh/remotehost-proxy.ctl" ]]; then
    ssh -T -O "exit" remotehost-proxy
  fi
}
function run_flyway_migration() {
  docker context use "default"
  if [[ -z "$(docker network list -q -f 'name=api-backend')" ]]; then
    docker network create --driver bridge api-backend
    NETWORK_CREATED=true
  fi
  if docker compose -p flyway --project-directory "${GITHUB_WORKSPACE:-./}" -f "${FLYWAY_DOCKER_COMPOSE_FILE}" run --rm flyway; then
    ERRORED=false
  fi
  if [[ ${NETWORK_CREATED} == true ]]; then
    docker network rm api-backend || true
  fi
  if [[ ${ERRORED} != false ]]; then
    error_log "Flyway migration failed"
    return 1
  fi
}

create_mysql_tunnel() {
  rm -f ~/.ssh/remotehost-proxy.ctl

  # Set up the configuration for ssh tunneling to the bastion server
  configure_bastion_ssh_tunnel

  # Start the ssh tunnel for MySQL
  set_env BINDHOST "0.0.0.0"
  set_env JDBC_LOCAL_PORT "33307"
  open_bastion_ssh_tunnel
}

setup_local_mysql_route_variables() {
  # Get the local hosts IP
  if [[ -f '/sbin/ip' ]]; then
    # DOCKERHOST="$(/sbin/ip route | awk '/default/ { print  $3}')"
    DOCKERHOST="$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"
    echo "Using the docker hosts ethernet IP ${DOCKERHOST} for accessing mysql"

  else
    DOCKERHOST=127.0.0.1
    echo "Using the docker hosts local IP ${DOCKERHOST} for accessing mysql"
  fi
  set_env DOCKERHOST "127.0.0.1"

  # Set the mysql host to the docker host to use the tunnel
  set_env JDBC_HOST_ORIGINAL "${JDBC_HOST}"
  set_env JDBC_PORT_ORIGINAL "${JDBC_PORT}"
  set_env JDBC_HOST "${DOCKERHOST}"
  set_env JDBC_PORT "${JDBC_LOCAL_PORT}"
}
