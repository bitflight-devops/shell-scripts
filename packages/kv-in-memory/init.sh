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

KV_FILESTORE_DIR="${KV_FILESTORE_DIR:-${HOME}/.kv-filestore}"
KV_FILESTORE_FILE="${KV_FILESTORE_FILE:-kv-filestore-${KV_FILESTORE_CONTEXT:-default}}"

kv_filestore() {
  local -r kv_filestore_dir="${1?Missing kv_filestore_dir argument}"
  local -r kv_filestore_file="${2?Missing kv_filestore_file argument}"
  local -r kv_filestore_key="${3?Missing kv_filestore_key argument}"
  local -r kv_filestore_value="${4?Missing kv_filestore_value argument}"

  local -r kv_filestore_file_path="${kv_filestore_dir}/${kv_filestore_file}"
  local -r kv_filestore_file_path_tmp="${kv_filestore_file_path}.tmp"

  if [[ ! -d "${kv_filestore_dir}" ]]; then
    mkdir -p "${kv_filestore_dir}"
  fi

  if [[ ! -f "${kv_filestore_file_path}" ]]; then
    touch "${kv_filestore_file_path}"
  fi

  if [[ -z "${kv_filestore_value}" ]]; then
    # Get value
    grep -E "^${kv_filestore_key}=" "${kv_filestore_file_path}" | cut -d "=" -f 2
  else
    # Set value
    grep -vE "^${kv_filestore_key}=" "${kv_filestore_file_path}" > "${kv_filestore_file_path_tmp}"
    echo "${kv_filestore_key}=${kv_filestore_value}" >> "${kv_filestore_file_path_tmp}"
    mv "${kv_filestore_file_path_tmp}" "${kv_filestore_file_path}"
  fi
}
