#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z ${SCRIPTS_LIB_DIR:-}   ]]; then
  LC_ALL=C
  export LC_ALL
  set +e
  read -r -d '' GET_LIB_DIR_IN_ZSH <<- 'EOF'
	0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
	0="${${(M)0:#/*}:-$PWD/$0}"
	SCRIPTS_LIB_DIR="${0:a:h}"
	SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
	EOF
  set -e
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
  if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
    # We are running in zsh
    eval "${GET_LIB_DIR_IN_ZSH}"
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi
# SCRIPTS_LIB_DIR

# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${LOG_FUNCTIONS_LOADED:=1}"

[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${COLOR_AND_EMOJI_VARIABLES_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/color_and_emoji_variables.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"
[[ -z ${YAML_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/yaml_functions.sh"

print_function_name() {
  local level="${1:-0}"
  if [[ -n ${FUNCNAME[${level}]}   ]]; then
    printf '%s\n' "${FUNCNAME[${level}]}"
  else
    printf '%s\n' "${funcstack[@]:level:1}"
  fi
}

print_parent_of_current_func_name() {
  print_function_name 3
}
print_current_func_name() {
  print_function_name 2
}

# Certain string functions are used in this file
# so we create them here if they are not already loaded
# from lib/string_functions.sh

if ! command_exists uppercase; then
  uppercase() {
    tr '[:lower:]' '[:upper:]' <<< "${*}"
  }
fi

if ! command_exists lowercase; then
  lowercase() {
    tr '[:upper:]' '[:lower:]' <<< "${*}"
  }
fi

if ! command_exists iscolorcode; then
  iscolorcode() {
    grep -q -E $'\e\\[''(?:[0-9]{1,3})(?:(?:;[0-9]{1,3})*)?[mGK]' <<< "$1"
  }
fi

if ! command_exists colorcode; then
  colorcode() {
    local -r color="${1}"
    if iscolorcode "${color}"; then
      perl -pe 's/(^\s*|\s*$)/Y/g;' <<< "${color}"
    elif [[ -n ${color:-} ]]; then
      local -r color_var_name="$(uppercase "${color}")"
      eval 'local resolved_color="${'"${color_var_name}"':-}"'
      if [[ -n ${resolved_color:-} ]] && iscolorcode "${colorcode}"; then
        perl -pe 's/(^\s*|\s*$)//gm;' <<< "${colorcode}"
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
  mkdir -p "${log_file_dir}" 2> /dev/null || true
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
  command -v "$@" > /dev/null 2>&1
}

running_in_github_actions() {
  [[ -n ${GITHUB_ACTIONS:-} ]]
}

running_in_ci() {
  [[ -n ${CI:-} ]]
}

get_log_type() {
  set +x
  LOG_TYPES=(
    "error"
    "warning"
    "notice"
    "debug"
  )
  if [[ -z ${GITHUB_ACTIONS:-} ]]; then
    LOG_TYPES+=(
      "info"
      "success"
      "failure"
      "step"
      "question"
      "pass"
      "fail"
      "skip"
      "starting"
      "finished"
      "result"
    )
  fi
  local -r logtype="$(tr '[:upper:]' '[:lower:]' <<< "${1}")"
  if [[ ${LOG_TYPES[*]} =~ ( |^)"${logtype}"( |$) ]]; then
    printf '%s' "${logtype}"
  else
    echo ""
  fi
}
# shellcheck disable=SC2034
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
  LOG_COLOR_starting="${COLOR_BOLD_CYAN}"
  LOG_COLOR_step="${COLOR_BRIGHT_CYAN}"
  LOG_COLOR_question="${tty_underline}${COLOR_BOLD_MAGENTA}"
  LOG_COLOR_pass="${COLOR_GREEN}"
  LOG_COLOR_fail="${COLOR_RED}"
  LOG_COLOR_skipped="${COLOR_YELLOW}"
  LOG_COLOR_failure="${COLOR_BOLD_RED}"
  LOG_COLOR_success="${COLOR_BOLD_YELLOW}"
  LOG_COLOR_finished="${COLOR_BOLD_CYAN}"
  LOG_COLOR_result="${COLOR_BOLD_WHITE}"
  local arg="$(tr '[:upper:]' '[:lower:]' <<< "${1}")"

  if [[ ! ${arg} =~ (success|failure|step|result|finished|starting) ]]; then
    local -r logtype="$(get_log_type "${arg}")"
  else
    local -r logtype="${arg}"
  fi
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
      final_style="${NOTICE_ICON:-}"
      ;;
    starting)
      style=" "
      final_style="${STARTING_ICON:-}"
      ;;
    finished)
      style=" "
      final_style="${FINISHED_ICON:-}"
      ;;
    result)
      style=" "
      final_style="${RESULT_ICON:-}"
      ;;
    step)
      style=" "
      final_style="${STEP_ICON:-}"
      ;;
    question)
      style=" "
      final_style="${QUESTION_ICON:-}"
      ;;
    failure)
      style=" "
      final_style="${FAILURE_ICON:-}"
      ;;
    success)
      style=" "
      final_style="${SUCCESS_ICON:-}"
      ;;
    pass)
      style=" "
      final_style="${PASS_ICON:-}"
      ;;
    fail)
      style=" "
      final_style="${FAIL_ICON:-}"
      ;;
    skipped)
      style=" "
      final_style="${SKIP_ICON:-}"
      ;;
    info)
      style=" "
      final_style="${INFO_ICON:-}"
      # logtype=''
      ;;
    debug)
      style="-"
      final_style="${DEBUG_ICON:-}"
      ;;
    *)
      style=""
      final_style="-->"
      ;;
  esac
  local -r indent_length="$((width - ${#logtype}))"
  printf '%s' "$(tr '[:lower:]' '[:upper:]' <<< "${logtype}")"
  printf -- "${style}%.0s" $(seq "${indent_length}")
  printf '%s' "${final_style}"
}

plain_log() {
  set +x
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<< "${1}")"
  shift
  local -r logtypeUppercase="$(tr '[:lower:]' '[:upper:]' <<< "${fulllogtype}")"
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
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<< "${1}")"
  local -r logtype="$(get_log_type "${1}")"
  shift

  if [[ $(type escape_github_command_data) == *function* ]] && [[ -n ${logtype} ]]; then
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
      if [[ $(type escape_github_command_property) == *'function'* ]] && [[ -n ${logtype} ]]; then
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
      perl -pe 'tr/ //s;s/::\s*/::/g;' <<< "${LOG_STRING[*]}::${msg}"
    else
      plain_log "${fulllogtype}" "${msg}"
    fi
  fi
}

# shellcheck disable=SC2120
to_stderr() {
  if [[ $# -eq 0 ]]; then
    echo >&2 "$(< /dev/stdin)"
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
  local labelUppercase
  labelUppercase="$(uppercase "${1}")"
  shift
  if iscolorcode "$(colorcode "${1}")"; then
    local -r color="$(colorcode "${1}")"
  else
    local -r color=""
  fi
  shift
  local msg="${*}"
  local -r logtype="$(get_log_type "${labelUppercase}")"
  local space
  if caller 1 > /dev/null 2>&1; then
    local function_name="$(caller 1 | awk '{print $2}')"
    [[ ${function_name} =~ ^(bash|source)$ ]] && unset function_name
  fi
  if running_in_github_actions && [[ -n ${logtype} ]]; then
    github_log "${labelUppercase}" "${function_name:+${function_name}():}${msg}"
  else
    indent_width=7
    printf -v space "%*s" "$((indent_width))" ''
    local msg="$(awk -v space="${space:-}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<< "${*}")"
    printf "%s[%s%5s%s] %s%s\n" "${COLOR_RESET:-}" "${color:-}" "${labelUppercase}" "${COLOR_RESET:-}" "${function_name:+${function_name}: }" "${msg}"
  fi
  if ! running_in_github_actions; then
    {
      nocolor_msg="$(stripcolor "${msg}")"
      timestamp_log "${labelUppercase}" "${function_name:+${function_name}():}" "${nocolor_msg}" >> "$(logfileName "${return_code}")" 2>&1 &
      disown
    } 2> /dev/null
  fi
}

debug() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "DEBUG" "COLOR_BOLD_BLACK" "✎ ${*}"
}
debug_log() { debug "${@}"; }

info_log() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "INFO" "COLOR_BOLD_WHITE" "★ ${*}"
}
info() { info_log "${@}"; }

notice() {
  local -r return_code=$?
  [[ $# -eq 0 ]] && return 0 # Exit if there is nothing to print
  log_output "${return_code}" "NOTICE" "COLOR_BOLD_WHITE" "${*}"
}
notice_log() { notice "${@}"; }

error_log() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_RED" "✗ ${*}" | to_stderr
}
error() { error_log "${@}"; }

fatal_log() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "ERROR" "COLOR_BOLD_RED" "FATAL: ${FATAL_ICON:-} ${*}" | to_stderr
  exit "${return_code}"
}

fatal() { fatal_log "${@}"; }

warn_log() {
  local return_code=$?
  [[ $# -eq 0 ]] && return 0                        # Exit if there is nothing to print
  [[ ${return_code} -eq 0 ]] && local return_code=1 # if we don't have the real return code, then make it an error
  log_output "${return_code}" "WARN" "COLOR_YELLOW" "∴ ${*}" | to_stderr
}
warning_log() { warn_log "${@}"; }
warn() { warn_log "${@}"; }
warning() { warn_log "${@}"; }
failure() {
  if [[ $1 =~ ^[\d]+$ ]] && [[ $1 -gt 0 ]]; then
    local -r return_code="$1"
    shift
  fi
  local -r message="${*}"
  log_output "${return_code}" "FAILURE" "COLOR_BRIGHT_RED" "${FAILURE_ICON} ${COLOR_BRIGHT_RED}${message}${COLOR_RESET}"
}

success() {
  local -r message="${*}"
  log_output "0" "SUCCESS" "COLOR_BRIGHT_YELLOW" "${SUCCESS_ICON} ${COLOR_BRIGHT_YELLOW}${message}${COLOR_RESET}" 2>&1
}

starting() {
  local -r message="${*}"
  log_output "0" "STARTING" "COLOR_YELLOW" "${START_ICON} ${message}${COLOR_RESET}" 2>&1

}

finished() {
  local -r message="${*}"
  log_output "0" "FINISHED" "COLOR_YELLOW" "${DONE_ICON} ${message}${COLOR_RESET}" 2>&1
}

step() {
  local -r message="${*}"
  log_output "0" "STEP   " "COLOR_CYAN" "${STEP_ICON} ${message}${COLOR_RESET}" 2>&1
}

step_question() {
    local -r message="${*}"
    log_output "0" "QUESTION" "COLOR_CYAN" "${STEP_ICON} ${message}${COLOR_RESET}" 2>&1
}

step_passed() {
  local -r message="${*}"
  log_output "0" "PASS   " "COLOR_BOLD_GREEN" "${PASS_ICON} ${COLOR_RESET}${message}${COLOR_RESET}" 2>&1
}

step_failed() {
  local -r message="${*}"
    log_output "0" "FAIL   " "COLOR_BOLD_RED" "${FAIL_ICON} ${COLOR_RESET}${message}${COLOR_RESET}" 2>&1
}

step_skipped() {
  local -r message="${*}"
    log_output "0" "SKIPPED " "COLOR_BOLD_CYAN" "${SKIP_ICON} ${COLOR_RESET}${message}${COLOR_RESET}" 2>&1

}

result() {
  local -r message="${*}"
    log_output "0" "RESULT  " "COLOR_BOLD_CYAN" "${RESULT_ICON} ${COLOR_RESET}${message}${COLOR_RESET}" 2>&1

}

pipe_errors_to_github_workflow() {
  local -r log_file_path="$(tr -s '/' <<< "${1}")"
  if [[ ${GITHUB_FILE_PROCESSED} == 'true' ]]; then
    cat "${log_file_path}"
  elif [[ -f "${SCRIPTS_LIB_DIR}/parse_logs.perl" ]]; then
    perl "${SCRIPTS_LIB_DIR}/parse_logs.perl" "${log_file_path}" || error "error parsing log file: ${log_file_path}"
  else
    error_log "Perl log parsing script not found: ${SCRIPTS_LIB_DIR}/parse_logs.perl"
    cat "${log_file_path}"
  fi
}

# Remove leading words from a version string. This function is used to
# remove leading words from version strings, such as "v1.0" or "version 2.0".
# The function is used to remove the leading "v" or "version" words from
# version strings.
remove_leading_words() {
  local version="$1"
  echo "${version}" | sed 's/^[a-zA-Z\-_ \t]*//'
}

print_single_log_file() {
  export GITHUB_LOG_FILE="${1}"
  if [[ -f ${GITHUB_LOG_FILE} ]]; then
    if running_in_github_actions; then
      short_filename="$(/usr/bin/dirname "${GITHUB_LOG_FILE}")"
      echo "::group::📄 ${short_filename}"

      if [[ -f "${GITHUB_LOG_FILE}.processed" ]]; then
        export GITHUB_FILE_PROCESSED='true'
      fi

      local version_label=${VERSION_ID:-${VERSION_LABEL:-${DEPLOY_VERSION:-}}} # DEPLOY_VERSION is deprecated
      export GITHUB_LOG_TITLE="${version_label:-${GITHUB_ACTION:-${short_filename:-}}}"

      pipe_errors_to_github_workflow "${GITHUB_LOG_FILE}" && touch "${GITHUB_LOG_FILE}.processed"
      unset GITHUB_FILE_PROCESSED
      unset ERROR_LOG_TITLE
      unset ERROR_LOG_FILE
      echo "::endgroup::"
    else
      info_log "Log file contents: ${GITHUB_LOG_FILE}\n$(cat "${GITHUB_LOG_FILE}")"
    fi
  fi
}

log_file_contents() (
  set +x +e
  export GITHUB_LOG_FILE_RAW="$(tr -s '/' <<< "${1}")"
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
  user="$(id -un 2> /dev/null || true)"

  local sh_c=()
  if [[ ${user} != 'root' ]]; then
    if command_exists sudo; then
      sh_c=('sudo')
    else
      cat >&2 <<- 'EOF'
				Error: this command needs the ability to run other commands as root.
				We are unable to find "sudo" available to make this happen.
			EOF
      exit 1
    fi
  fi
  "${sh_c[@]}" "${@}"
}
