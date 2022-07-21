#!/usr/bin/env bash
# Current Script Directory
if [[ -z ${SCRIPTS_LIB_DIR} ]]; then
  if grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; then
    # shellcheck disable=SC2296
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  fi
fi

[[ -z ${SYSTEM_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${COLOR_AND_EMOJI_VARIABLES_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/color_and_emoji_variables.sh"
[[ -z ${STRING_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"
[[ -z ${YAML_FUNCTIONS_LOADED} ]] && source "${SCRIPTS_LIB_DIR}/yaml_functions.sh"

if [[ -z ${LOG_DIR} ]]; then
  if is_darwin; then
    LOG_DIR=/usr/local/var/log/shell_logs
  else
    LOG_DIR="${LOG_DIR:-/var/log/shell_logs}"
  fi
fi

function logfileDir() {
  local parent_command="$([[ ${PPID} -gt 0 ]] && ps -o comm= "${PPID}")"
  local this_command="$(ps -o comm= $$)"

  if [[ ${this_command} == "bash" ]] && [[ ${parent_command} == "bash" ]]; then
    unset parent_command
  fi
  # echo "Commands:"
  # sed 's/\x0/ \n/g' "/proc/$$/cmdline"
  # echo "endcommand:"
  local log_file_dir=$(printf '%s%s/%s' "${LOG_DIR}" "${parent_command:+/${parent_command}}" "${this_command}" | tr -s '/')
  mkdir -p "${log_file_dir}" 2>/dev/null || true
  printf '%s' "${log_file_dir}"
}

# logfileName [return code | name override] [name override]
function logfileName() {
  local log_file_name="main"
  local suffix=".log"
  if [[ $1 =~ ^[0-9]+$ ]] && [[ $1 -gt 0 ]]; then
    suffix=".error"
    shift
  fi

  if [[ $# -gt 0 ]]; then
    local log_file_name="$*"
  fi
  log_file_name="${log_file_name//[^a-zA-Z0-9]/_}"

  log_file_name=$(printf '%s/%s%s' "$(logfileDir)" "${log_file_name:-main}" "${suffix}" | tr -s '/')
  touch "${log_file_name}" && echo "${log_file_name}"
}

function whatIsMyName() {
  ps --no-headers -o command $$
}

# Check if the command is available in this shell
command_exists() {
  command -v "$@" >/dev/null 2>&1
}

running_in_github_actions() {
  [[ -n ${GITHUB_ACTIONS} ]]
}

running_in_ci() {
  [[ -n ${CI} ]]
}

getLogType() {
  set +x
  LOG_TYPES=(
    "error"
    "info"
    "warning"
    "notice"
    "debug"
  )
  logtype="${1}"
  if echo "${LOG_TYPES[@]}" | grep -w -q -i "${logtype}"; then
    tr '[:upper:]' '[:lower:]' <<<"${logtype}"
  else
    echo ""
  fi
}

# Arguments:
#   $1: Log type
#   $*: Log message
## example: timestamp "error" "Something went wrong"
## output: 2022-07-17T14:59:56-0400 [ERROR] Something went wrong
timestamp_log() {
  local -r logtype="$(getLogType "${1}")"
  shift
  local -r logtypeUppercase="$(tr '[:lower:]' '[:upper:]' <<<"${logtype}")"
  local -r msg="${*}"
  local -r timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
  printf "%s [%s] %s\n" "${timestamp}" "${logtypeUppercase}" "${msg}"
}

join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "${f}" "${@/#/${d}}"
  fi
}

github_log() {
  local -r logtype="$(getLogType "${1}")"
  shift

  if [[ $(type -t escape_github_command_data) == 'function' ]]; then
    local -r msg="$(escape_github_command_data "$(trim "${*}")")"
  else
    local -r msg="${*}"
  fi

  if [[ ${#msg} -gt 0 ]]; then
    if [[ ${#logtype} -gt 0 ]]; then
      LOG_ARGS=()
      LOG_STRING=("::${logtype} ")
      shift
      FILE="$(trim "${GITHUB_LOG_FILE:-${BASH_SOURCE[0]}}")"
      if [[ $(type -t escape_github_command_property) == 'function' ]]; then
        [[ ${#FILE} -gt 0 ]] && LOG_ARGS+=("file=$(escape_github_command_property "${FILE}")")
        [[ -n ${GITHUB_LOG_TITLE:-} ]] && LOG_ARGS+=("title=$(escape_github_command_property "${GITHUB_LOG_TITLE}")")
      else
        [[ ${#FILE} -gt 0 ]] && LOG_ARGS+=(file="${FILE}")
        [[ -n ${GITHUB_LOG_TITLE:-} ]] && LOG_ARGS+=(title="${GITHUB_LOG_TITLE}")
      fi
      if [[ ${#LOG_ARGS[@]} -gt 0 ]]; then
        ARGS="$(join_by , "${LOG_ARGS[@]}")"
        LOG_STRING+=("${ARGS}")
      fi
      perl -pe 'tr/ //s;s/::\s*/::/g;' <<<"${LOG_STRING[*]}::${msg}"
    else
      timestamp_log "${logtype}" "${msg}"
    fi
  fi
}

# trunk-ignore(shellcheck/SC2120)
toStdErr() {
  if [[ $# -eq 0 ]]; then
    echo >&2 "$(</dev/stdin)"
  else
    echo >&2 "${*}"
  fi
}

# Arguments:
#   $1: Return Code
#   $2: Log Type Label [debug, info, warning,...]
#   $3: Log Highlight Label Color
#   $*: Log Message
# example: log_output 1 "error" "red" "Something went wrong"
log_output() {
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  local -r return_code=${1:?}
  shift
  local -r labelUppercase="$(uppercase "${1}")"
  shift
  if iscolorcode "$(colorcode "${1}")"; then
    local -r color="${1}"
    shift
  else
    local -r color=""
  fi
  local msg="${*}"

  if caller 1 >/dev/null 2>&1; then
    local -r function_name="$(caller 1 | awk '{print $2}')"
  fi
  if running_in_github_actions; then
    github_log "${labelUppercase}" "${COLOR_RESET:-}" "${function_name:+${function_name}:}" "${msg}"
  else
    printf "[%s%5s%s] %s%s\n" "${color:-}" "${labelUppercase}" "${COLOR_RESET:-}" "${function_name:+${function_name}:}" "${msg}"
  fi

  {
    nocolor_msg="$(stripcolor "${msg}")"
    timestamp_log "${labelUppercase}" "${function_name:+${function_name}:}" "${nocolor_msg}" >>"$(logfileName "${return_code}")" 2>&1 &
    disown
  } 2>/dev/null
}

debug() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "DEBUG" "COLOR_BOLD_BLACK" "✎ ${*}"
}

info() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "INFO" "COLOR_BOLD_WHITE" "★ ${*}"
}

notice() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "NOTICE" "COLOR_BOLD_WHITE" "${*}"
}

error() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_RED" "✗ ${*}" | toStdErr
}

fatal() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_BOLD_RED" "FATAL: ☠️ ${*}" | toStdErr
}

warn() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "WARN" "COLOR_YELLOW" "∴ ${*}" | toStdErr
}

failure() {
  local -r message="${*}"
  if [[ $1 =~ ^[\d]+$ ]] && [[ $1 -gt 0 ]]; then
    local -r return_code="$1"
    shift
  fi
  log_output "${return_code}" "FAILURE" "COLOR_BRIGHT_RED" "${CROSS_MARK} ${COLOR_BRIGHT_RED}${message}${COLOR_RESET}"
}

success() {
  local -r message="${*}"
  log_output "0" "SUCCESS" "${COLOR_BRIGHT_YELLOW:-}" "${CHECK_MARK_BUTTON} ${COLOR_BRIGHT_YELLOW}${message}${COLOR_RESET}" 2>&1
}

pipe_errors_to_github_workflow() {
  local -r log_file_path="${1}"
  if [[ ${GITHUB_FILE_PROCESSED} == 'true' ]]; then
    cat "${log_file_path}"
  else
    perl "${FUNCTIONS_DIR}/parse_logs.perl" "${log_file_path}" || error "error parsing log file: ${log_file_path}"
  fi
}

print_single_log_file() {
  export GITHUB_LOG_FILE="${1}"
  if [[ -f ${GITHUB_LOG_FILE} ]]; then
    if running_in_github_actions; then
      short_filename="$(basename "${GITHUB_LOG_FILE}")"
      echo "::group::📄 ${short_filename}"

      if [[ -f "${GITHUB_LOG_FILE}.processed" ]]; then
        export GITHUB_FILE_PROCESSED='true'
      fi

      export GITHUB_LOG_TITLE="${DEPLOY_VERSION:-${GITHUB_ACTION:-${short_filename:-}}}"

      pipe_errors_to_github_workflow "${GITHUB_LOG_FILE}" && touch "${GITHUB_LOG_FILE}.processed"
      unset GITHUB_FILE_PROCESSED
      unset ERROR_LOG_TITLE
      unset ERROR_LOG_FILE
      echo "::endgroup::"
    else
      info "Log file contents: ${GITHUB_LOG_FILE}\n$(cat "${GITHUB_LOG_FILE}")"
    fi
  fi
}

log_file_contents() (
  set +x +e
  export GITHUB_LOG_FILE_RAW="${1}"
  find "$(dirname "${GITHUB_LOG_FILE_RAW}")" -type f -iname "$(basename "${GITHUB_LOG_FILE_RAW}")" -print0 | while IFS= read -r -d $'\0' file; do
    print_single_log_file "${file}"
  done
  return 0
)

print_logs_from_zip() {
  local -r extracted_logs_root_path="${1}"
  if [[ -d ${extracted_logs_root_path} ]]; then
    log_file_contents "${extracted_logs_root_path}/var/log/eb-engine.log"
    log_file_contents "${extracted_logs_root_path}/var/log/wearsafe*.log"
    log_file_contents "${extracted_logs_root_path}/var/log/platform/*.log"
    log_file_contents "${extracted_logs_root_path}/var/log/procfile*.log"
    log_file_contents "${extracted_logs_root_path}/var/log/web*.log"
    log_file_contents "${extracted_logs_root_path}/var/log/cloud-init-output.log"
    log_file_contents "${extracted_logs_root_path}/var/log/eb-cfn-init-call.log"
    log_file_contents "${extracted_logs_root_path}/var/log/nginx/error.log"
    log_file_contents "${extracted_logs_root_path}/var/log/tomcat/catalina.*.log"
  fi
}

run_as_root() {
  user="$(id -un 2>/dev/null || true)"

  export sh_c=""
  if [[ ${user} != 'root' ]]; then
    if command_exists sudo; then
      export sh_c='sudo'
    else
      cat >&2 <<-'EOF'
				Error: this command needs the ability to run other commands as root.
				We are unable to find "sudo" available to make this happen.
			EOF
      exit 1
    fi
  fi
  ${sh_c} "${@}"
}

export LOG_FUNCTIONS_LOADED=1
