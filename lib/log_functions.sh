#!/usr/bin/env bash
# Current Script Directory
if [[ -n ${BFD_REPOSITORY:-} ]] && [[ -d ${BFD_REPOSITORY} ]]; then
  : "${SCRIPTS_LIB_DIR:="${BFD_REPOSITORY}/lib"}"
fi
if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if command -v zsh > /dev/null 2>&1 && [[ $(${SHELL} -c 'echo ${ZSH_VERSION}') != '' ]] || {
     command -v ps > /dev/null 2>&1 && grep -q 'zsh' <<< "$(ps -c -ocomm= -p $$)"
  }; then
    # We are running in zsh
    # shellcheck disable=SC2296,SC2299,SC2250,SC2296,SC2299,SC2277,SC2298
    # trunk-ignore(shfmt/parse)
    0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
    # shellcheck disable=SC2296,SC2299,SC2250,SC2296,SC2299,SC2277,SC2298
    0="${${(M)0:#/*}:-$PWD/$0}"
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi
export SCRIPTS_LIB_DIR
export BFD_REPOSITORY="${BFD_REPOSITORY:-${SCRIPTS_LIB_DIR%/lib}}"
export LOG_FUNCTIONS_LOADED=1
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${COLOR_AND_EMOJI_VARIABLES_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/color_and_emoji_variables.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"
[[ -z ${YAML_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/yaml_functions.sh"

# Certain string functions are used in this file
# so we create them here if they are not already loaded
# from lib/string_functions.sh

if ! command -v uppercase >/dev/null 2>&1; then
  uppercase() {
    tr '[:lower:]' '[:upper:]' <<<"${*}"
  }
fi


if ! command -v lowercase >/dev/null 2>&1; then
lowercase() {
  tr '[:upper:]' '[:lower:]' <<<"${*}"
}
fi


if ! command -v iscolorcode >/dev/null 2>&1; then
iscolorcode() {
  grep -q -E $'\e\\[''(?:[0-9]{1,3})(?:(?:;[0-9]{1,3})*)?[mGK]' <<<"$1"
}
fi


if ! command -v colorcode >/dev/null 2>&1; then
colorcode() {
  local -r color="${1}"
  if iscolorcode "${color}"; then
    perl -pe 's/(^\s*|\s*$)/Y/g;' <<<"${color}"
  elif [[ -n ${color:-} ]]; then
    local -r color_var_name="$(uppercase "${color}")"
    eval 'local resolved_color="${'"${color_var_name}"':-}"'
    if [[ -n ${resolved_color:-} ]] && iscolorcode "${colorcode}"; then
      perl -pe 's/(^\s*|\s*$)//gm;' <<<"${colorcode}"
    elif [[ -z ${DEBUG:-} ]]; then
      printf '%s' "${resolved_color}"
    else
      printf ''
    fi
  fi
}
fi

function logfileDir() {
  local parent_command="$([[ ${PPID} -gt 0 ]] && ps -o comm= "${PPID}")"
  local this_command="$(ps -o comm= $$)"

  if [[ -z ${LOG_DIR:-} ]] && command_exists uname; then
    case "$(uname -s)" in
    *darwin* | *Darwin*) LOG_DIR=/usr/local/var/log/shell_logs ;;
    *) LOG_DIR="${LOG_DIR:-/var/log/shell_logs}" ;;
    esac
  fi

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
  [[ -n ${GITHUB_ACTIONS:-} ]]
}

running_in_ci() {
  [[ -n ${CI:-} ]]
}

# Duplicate of function in lib/log_functions.sh
get_log_type() {
  set +x
  LOG_TYPES=(
    "error"
    "warning"
    "notice"
    "debug"
  )
  if [[ -z ${GITHUB_ACTIONS-} ]]; then
    LOG_TYPES+=(
      "info"
      "success"
      "failure"
      "step"
    )
  fi
  local -r logtype="$(tr '[:upper:]' '[:lower:]' <<<"${1}")"
  if [[ ${LOG_TYPES[*]} =~ ( |^)"${logtype}"( |$) ]]; then
    printf '%s' "${logtype}"
  else
    echo ""
  fi
}

get_log_color() {
  if [[ -n ${GITHUB_ACTIONS:-} ]]; then
    printf '%s' "::"
    return
  elif [[ -n ${CI:-} ]]; then
    printf '%s' "##"
    return
  fi

  LOG_COLOR_error="${RED}"
  LOG_COLOR_info="${GREEN}"
  LOG_COLOR_warning="${YELLOW}"
  LOG_COLOR_notice="${MAGENTA}"
  LOG_COLOR_debug="${GREY}"
  LOG_COLOR_step="${COLOR_BOLD_CYAN}"
  LOG_COLOR_failure="${COLOR_BG_YELLOW}${RED}"
  LOG_COLOR_success="${COLOR_BOLD_YELLOW}"
  local arg="$(tr '[:upper:]' '[:lower:]' <<<"${1}")"
  local -r logtype="$(get_log_type "${arg}")"

  if [[ -z ${logtype} ]]; then
    printf '%s' "${NO_COLOR}"
  else
    eval 'printf "%s" "${LOG_COLOR_'"${logtype}"'}"'
  fi
}

indent_style() {
  local logtype="${1}"
  local -r width="${2}"

  local final_style=''
  case "${logtype}" in
  notice)
    style=" "
    final_style="${STARTING_STAR}"
    ;;
  step)
    style=" "
    final_style="${STEP_STAR}"
    ;;
  failure)
    style=" "
    final_style="${CROSS_MARK}"
    ;;
  success)
    style=" "
    final_style="${CHECK_MARK_BUTTON}"
    ;;
  info)
    style=" "
    final_style="${INFO_ICON} "
    ;;
  debug)
    style="-"
    final_style="${DEBUG_ICON:-} "
    ;;
  *)
    style=""
    final_style="-->"
    ;;
  esac
  local -r indent_length="$((width - ${#logtype}))"
  printf '%s' "$(tr '[:lower:]' '[:upper:]' <<<"${logtype}")"
  printf -- "${style}%.0s" $(seq "${indent_length}")
  printf '%s' "${final_style}"
}

simple_log() {
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<<"${1}")"
  local -r logtype="$(get_log_type "${1}")"
  local -r logcolor="$(get_log_color "${logtype}")"
  if [[ -z ${logtype} ]]; then
    plain_log "${fulllogtype}" "${*}"
  else
    shift
    if [[ ${logcolor} != "::" ]]; then
      local indent_width=11
      local indent="$(indent_style "${logtype}" "${indent_width}")"
      printf -v log_prefix '%s%s%s%s%s' "${BOLD}" "${logcolor}" "${indent}" "${logcolor}" "${NO_COLOR}"
      # log_prefix_length="$(stripcolor "${log_prefix}" | wc -c)"
      printf -v space "%*s" "$((indent_width + 2))" ''
      local msg="$(awk -v space="${space}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<<"${*}")"
    else
      printf -v log_prefix '::%s ::' "${logtype}"
      local -r msg="$(escape_github_command_data "${*}")"
    fi
    printf '%s%s\n' "${log_prefix}" "${msg}"
  fi
}

plain_log() {
  set +x
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<<"${1}")"
  shift
  local -r logtypeUppercase="$(tr '[:lower:]' '[:upper:]' <<<"${fulllogtype}")"
  local -r msg="${*}"

  printf "[%7s] %s\n" "${logtypeUppercase}" "${msg}"
}
# Arguments:
#   $1: Log type
#   $*: Log message
## example: timestamp "error" "Something went wrong"
## output: 2022-07-17T14:59:56-0400 [ERROR] Something went wrong
timestamp_log() {
  set +x
  local -r log_string="$(plain_log "${@}")"
  local -r timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
  printf "%s %s" "${timestamp}" "${log_string}"
}

join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "${f}" "${@/#/${d}}"
  fi
}

github_log() {
  set +x
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<<"${1}")"
  local -r logtype="$(get_log_type "${1}")"
  shift

  if [[ $(type -t escape_github_command_data) == 'function' ]] && [[ -n ${logtype} ]]; then
    local -r msg="$(escape_github_command_data "$(trim "${*}")")"
  else
    local -r msg="${*}"
  fi

  if [[ -n ${msg} ]]; then
    if [[ -n ${logtype} ]]; then
      LOG_ARGS=()
      LOG_STRING=("::${logtype} ")
      shift
      FILE="$(trim "${GITHUB_LOG_FILE:-${BASH_SOURCE[0]}}")"
      if [[ $(type -t escape_github_command_property) == 'function' ]] && [[ -n ${logtype} ]]; then
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
      plain_log "${fulllogtype}" "${msg}"
    fi
  fi
}

# shellcheck disable=SC2120
to_stderr() {
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
  set +x
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  local -r return_code=${1:?}
  shift
  local -r labelUppercase="$(uppercase "${1}")"
  shift
  if iscolorcode "$(colorcode "${1}")"; then
    local -r color="$(colorcode "${1}")"
  else
    local -r color=""
  fi
  shift
  local msg="${*}"
  local -r logtype="$(get_log_type "${labelUppercase}")"

  if caller 1 >/dev/null 2>&1; then
    local function_name="$(caller 1 | awk '{print $2}')"
    [[ ${function_name} =~ ^(bash|source)$ ]] && unset function_name
  fi
  if running_in_github_actions && [[ -n ${logtype} ]]; then
    github_log "${labelUppercase}" "${function_name:+${function_name}():}${msg}"
  else
    indent_width=7
    printf -v space "%*s" "$((indent_width))" ''
    local msg="$(awk -v space="${space}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<<"${*}")"
    printf "%s[%s%5s%s] %s%s\n" "${COLOR_RESET:-}" "${color:-}" "${labelUppercase}" "${COLOR_RESET:-}" "${function_name:+${function_name}: }" "${msg}"
  fi
  if ! running_in_github_actions; then
    {
      nocolor_msg="$(stripcolor "${msg}")"
      timestamp_log "${labelUppercase}" "${function_name:+${function_name}():}" "${nocolor_msg}" >>"$(logfileName "${return_code}")" 2>&1 &
      disown
    } 2>/dev/null
  fi
}

debug() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "DEBUG" "COLOR_BOLD_BLACK" "✎ ${*}"
}
debug_log() { debug "${@}"; }

info() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "INFO" "COLOR_BOLD_WHITE" "★ ${*}"
}
info_log() { info "${@}"; }

notice() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "NOTICE" "COLOR_BOLD_WHITE" "${*}"
}
notice_log() { notice "${@}"; }

error() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_RED" "✗ ${*}" | to_stderr
}
error_log() { error "${@}"; }

fatal() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_BOLD_RED" "FATAL: ☠️ ${*}" | to_stderr
}

fatal_log() { fatal "${@}"; }

warn() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "WARN" "COLOR_YELLOW" "∴ ${*}" | to_stderr
}
warning() { warn "${@}"; }

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
  log_output "0" "SUCCESS" "COLOR_BRIGHT_YELLOW" "${CHECK_MARK_BUTTON} ${COLOR_BRIGHT_YELLOW}${message}${COLOR_RESET}" 2>&1
}

pipe_errors_to_github_workflow() {
  local -r log_file_path="$(tr -s '/' <<<"${1}")"
  if [[ ${GITHUB_FILE_PROCESSED} == 'true' ]]; then
    cat "${log_file_path}"
  elif [[ -f "${SCRIPTS_LIB_DIR}/parse_logs.perl" ]]; then
    perl "${SCRIPTS_LIB_DIR}/parse_logs.perl" "${log_file_path}" || error "error parsing log file: ${log_file_path}"
  else
    error "Perl log parsing script not found: ${SCRIPTS_LIB_DIR}/parse_logs.perl"
    cat "${log_file_path}"
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
  export GITHUB_LOG_FILE_RAW="$(tr -s '/' <<<"${1}")"
  local logdir="$(dirname "${GITHUB_LOG_FILE_RAW}")"
  if [[ -d ${logdir} ]]; then
    find "${logdir}" -type f -iname "$(basename "${GITHUB_LOG_FILE_RAW}")" -print0 | while IFS= read -r -d $'\0' file; do
      print_single_log_file "${file}"
    done
  fi
  return 0
)

print_logs_from_zip() {
  local -r extracted_logs_root_path="${1%/}"
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
