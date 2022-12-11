#!/usr/bin/env bash
## <script src="https://get-fig-io.s3.us-west-1.amazonaws.com/readability.js"></script>
## <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/themes/prism-okaidia.min.css" rel="stylesheet" />
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-core.min.js" data-manual></script>
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-bash.min.js"></script>
## <style>body {color: #272822; background-color: #272822; font-size: 0.8em;} </style>

# This file should have no side effects or dependencies

command_exists() { command -v "$@" > /dev/null 2>&1; }
this_tput="$(command_exists tput && echo 'tput' || printf '')"
BOLD="$(this_tput bold 2> /dev/null || printf '')"
GREY="$(this_tput setaf 0 2> /dev/null || printf '')"
UNDERLINE="$(this_tput smul 2> /dev/null || printf '')"
RED="$(this_tput setaf 1 2> /dev/null || printf '')"
GREEN="$(this_tput setaf 2 2> /dev/null || printf '')"
YELLOW="$(this_tput setaf 3 2> /dev/null || printf '')"
BLUE="$(this_tput setaf 4 2> /dev/null || printf '')"
MAGENTA="$(this_tput setaf 5 2> /dev/null || printf '')"
COLOR_RESET="$(this_tput sgr0 2> /dev/null || printf '')"

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

# if test -t 1 && [[ $(this_tput colors 2>/dev/null || printf '0') -gt 0 ]]; then
  COLOR_BRIGHT_BLACK=$'\e[0;90m'
  COLOR_BRIGHT_RED=$'\e[0;91m'
  COLOR_BRIGHT_GREEN=$'\e[0;92m'
  COLOR_BRIGHT_YELLOW=$'\e[0;93m'
  COLOR_BRIGHT_BLUE=$'\e[0;94m'
  COLOR_BRIGHT_MAGENTA=$'\e[0;95m'
  COLOR_BRIGHT_CYAN=$'\e[0;96m'
  COLOR_BRIGHT_WHITE=$'\e[0;97m'
  COLOR_GREY=$'\x1b\x5b\x33\x30\x6d'
  COLOR_BLACK=$'\e[0;30m'
  COLOR_RED=$'\e[0;31m'
  COLOR_GREEN=$'\e[0;32m'
  COLOR_YELLOW=$'\e[0;33m'
  COLOR_BLUE=$'\e[0;34m'
  COLOR_MAGENTA=$'\e[0;35m'
  COLOR_CYAN=$'\e[0;36m'
  COLOR_WHITE=$'\e[0;37m'
  COLOR_BOLD_BLACK=$'\e[1;30m'
  COLOR_BOLD_RED=$'\e[1;31m'
  COLOR_BOLD_GREEN=$'\e[1;32m'
  COLOR_BOLD_YELLOW=$'\e[1;33m'
  COLOR_BOLD_BLUE=$'\e[1;34m'
  COLOR_BOLD_MAGENTA=$'\e[1;35m'
  COLOR_BOLD_CYAN=$'\e[1;36m'
  COLOR_BOLD_WHITE=$'\e[1;37m'
  COLOR_BOLD=$'\e[1m'
  COLOR_BOLD_YELLOW=$'\e[1;33m'
  COLOR_RESET=$'\e[0m'
  CLEAR_SCREEN="$(this_tput rc 2> /dev/null || printf '')"
  COLOR_BG_BLACK=$'\e[1;40m'
COLOR_BG_RED=$'\e[1;41m'
COLOR_BG_GREEN=$'\e[1;42m'
COLOR_BG_YELLOW=$'\e[1;43m'
COLOR_BG_BLUE=$'\e[1;44m'
COLOR_BG_MAGENTA=$'\e[1;45m'
COLOR_BG_CYAN=$'\e[1;46m'
COLOR_BG_WHITE=$'\e[1;47m'
# fi

#BASIC_ICONS
INFORMATION_ICON=$'\342\204\271'      # ℹ Information
GEAR_ICON=$'\342\232\231'             # ⚙ Gear
TOOLS_ICON=$'\342\232\222'            # ⚒ Tools
ITALIC_CROSS_ICON=$'\342\234\227'     # ✗ Italic Cross
SKULL_ICON=$'\xE2\x98\xA0'            # ☠ Skull and Crossbones
HAZARD_ICON=$'\342\232\240'           # ⚠ Hazard
BALLOT_TICK_ICON=$'\342\230\221'      # ☑ Ballot Box With Tick
BALLOT_CROSS_ICON=$'\342\230\222'     # ☒ Ballot Box With X
ELIPSIS_ICON=$'\342\200\246'          # … Elipsis
UMBRELLA_ICON=$'\342\230\202'         # ☂ Umbrella
CIRCLE_BULLET_ICON=$'\342\232\254'    # ⚬ Circle Bullet
HIDDEN_CIRCLE_ICON=$'\342\227\214'    # ◌ Hidden Circle
VISIBLE_CIRCLE_ICON=$'\342\227\213 '  # ○ Visible Circle
TRIANGLE_ICON=$'\342\226\276'         # ▾ Triangle
CROSS_ICON=$'\342\230\223'            # ☓ Cross
BOLD_CROSS_ICON=$'\342\234\226'       # ✖ Bold Cross
CHECK_ICON=$'\342\234\223'            # ✓ Check
SWORDS_ICON=$'\342\232\224'           # ⚔ Swords
SWERVE_ICON=$'\342\230\241'           # ☡ Swerve
STAR_OPEN_ICON=$'\342\230\206'        # ☆ Star Open
STAR_FILLED_ICON=$'\342\230\205'      # ★ Star Filled
LIGHTNING_ICON=$'\342\232\241'        # ⚡ Lightning
FLAG_ICON=$'\342\232\221'             # ⚑ Flag
HAND_PEN_ICON=$'\342\234\215'         # ✍ Hand Pen
PENCIL_ICON=$'\342\234\217'           # ✏ Pencil

# Mapped Icon Labels
SUCCESS_ICON=${SUCCESS_ICON:-${CHECK_ICON}}
FAILURE_ICON=${FAILURE_ICON:-${CROSS_ICON}}
FATAL_ICON=${FATAL_ICON:-${SKULL_ICON}}
WARNING_ICON=${WARNING_ICON:-${HAZARD_ICON}}
ERROR_ICON=${ERROR_ICON:-${ITALIC_CROSS_ICON}}
DEBUG_ICON=${DEBUG_ICON:-${GEAR_ICON}}
INFO_ICON=${INFO_ICON:-${INFORMATION_ICON}}
START_ICON=${START_ICON:-${STAR_FILLED_ICON}}
OPTION_ICON=${OPTION_ICON:-${VISIBLE_CIRCLE_ICON}}
STEP_ICON=${STEP_ICON:-${STAR_OPEN_ICON}}
PASS_ICON=${PASS_ICON:-${BALLOT_TICK_ICON}}
FAIL_ICON=${FAIL_ICON:-${BALLOT_CROSS_ICON}}
SKIP_ICON=${SKIP_ICON:-${HIDDEN_CIRCLE_ICON}}
IN_PROGRESS_ICON=${IN_PROGRESS_ICON:-${CIRCLE_BULLET_ICON}}
DONE_ICON=${DONE_ICON:-${FLAG_ICON}}
MAINTENANCE_ICON=${MAINTENANCE_ICON:-${TOOLS_ICON}}
PROBLEM_ICON=${PROBLEM_ICON:-${UMBRELLA_ICON}}
NOTICE_ICON=${NOTICE_ICON:-${LIGHTNING_ICON}}
RESULTS_ICON=${RESULTS_ICON:-${PENCIL_ICON}}
QUESTION_ICON=${QUESTION_ICON:-${HAND_PEN_ICON}}

# Taken from lib/github_core_functions.sh
escape_github_command_data() {
  # Escape the GitHub string variable character to %25
  # Escape any carrage returns to %0D
  # Escape any remaining newlines to %0A
  local -r data="${1}"
  printf '%s' "${data}" | perl -ne '$_ =~ s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g;print;'
}

get_log_type() {
  set +x
  LOG_TYPES=(
    "error"
    "info"
    "warning"
    "notice"
    "debug"
  )
  if [[ -z ${GITHUB_ACTIONS:-} ]]; then
    LOG_TYPES+=(
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

  LOG_COLOR_error="${COLOR_RED}"
  LOG_COLOR_info="${COLOR_GREEN}"
  LOG_COLOR_warning="${COLOR_YELLOW}"
  LOG_COLOR_notice="${COLOR_MAGENTA}"
  LOG_COLOR_debug="${COLOR_GREY}"
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
    printf '%s' "${COLOR_RESET}"
  else
    eval 'printf "%s" "${LOG_COLOR_'"${logtype}"'}"'
  fi
}

stripcolor() {
  # shellcheck disable=SC2001
  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" <<< "${*}"
}

execute() {
  if ! run_quietly "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
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
      style=" "
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

# convert to simple_log
if ! command_exists log_output; then
  log_output() {
    local -r ret_val="${1}"
    local -r log_label="$(tr '[:upper:]' '[:lower:]' <<< "${2}")"
    if command_exists "${log_label}"; then
      ${log_label} "${msg}"
    else
      simple_log "${log_label}" "${msg}"
    fi
    return "${ret_val}"
  }
fi

plain_log() {
  set +x
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<< "${1}")"
  shift
  local -r logtypeUppercase="$(tr '[:lower:]' '[:upper:]' <<< "${fulllogtype}")"
  local -r msg="$(sed -e 's/\\t/\t/g;s/\\n/\n/g' <<< "${*}")"

  printf "[%7s] %s\n" "${logtypeUppercase}" "${msg}"
}

simple_log() {
  in_quiet_mode && return 0
  local -r fulllogtype="$(tr '[:lower:]' '[:upper:]' <<< "${1}")"
  local -r logtype="$(get_log_type "${1}")"
  local -r logcolor="$(get_log_color "${logtype}")"
  local msg
  local space
  local log_prefix
  if [[ -z ${logtype} ]]; then
    plain_log "${fulllogtype}" "${*}"
  else
    shift
    msg="$(sed -e 's/\\t/\t/g;s/\\n/\n/g' <<< "${*}")"
    if [[ ${logcolor} != "::" ]]; then
      local indent_width=11
      local indent="$(indent_style "${logtype}" "${indent_width}")"
      printf -v log_prefix '%s%s%s%s%s' "${BOLD}" "${logcolor}" "${indent}" "${logcolor}" "${COLOR_RESET}"
      # log_prefix_length="$(stripcolor "${log_prefix}" | wc -c)"
      printf -v space "%*s" "$((indent_width + 2))" ''
      msg="$(awk -v space="${space:-}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<< "${msg}")"
    else
      printf -v log_prefix '::%s ::' "${logtype}"
      msg="$(awk -v space="${space:-}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<< "${msg}")"
      if [[ $(type escape_github_command_data) == *function* ]]; then
        msg="$(escape_github_command_data "${msg}")"
      fi
    fi
    printf '%s%s\n' "${log_prefix}" "${msg}"
  fi
}

if ! command_exists failure; then
  failure() {
    local -r message="${*}"
    simple_log failure "${COLOR_BOLD_RED:-}${message}${COLOR_RESET:-}"
  }
fi
if ! command_exists success; then
  success() {
    local -r message="${*}"
    simple_log success "${COLOR_BOLD_YELLOW:-}${message}${COLOR_RESET:-}" 2>&1
  }
fi
if ! command_exists starting; then
  starting() {
    local -r message="${*}"
    simple_log starting "${message}" 2>&1
  }
fi
if ! command_exists finished; then
  finished() {
    local -r message="${*}"
    simple_log finished "${message}" 2>&1
  }
fi
if ! command_exists step; then
  step() {
    local -r message="${*}"
    simple_log step "${message}" 2>&1
  }
fi
if ! command_exists step_question; then
  step_question() {
    local -r message="${*}"
    simple_log question "${message}" 2>&1
  }
fi
if ! command_exists step_passed; then
  step_passed() {
    local -r message="${*}"
    simple_log pass "${message}" 2>&1
  }
fi
if ! command_exists step_failed; then
  step_failed() {
    local -r message="${*}"
    simple_log fail "${message}" 2>&1
  }
fi
if ! command_exists step_skipped; then
  step_skipped() {
    local -r message="${*}"
    simple_log skipped "${message}" 2>&1
  }
fi
if ! command_exists result; then
  result() {
    local -r message="${*}"
    simple_log result "${message}" 2>&1
  }
fi
if ! command_exists abort; then
  abort() {
    simple_log "error" "$@" >&2
    exit 1
  }
fi

if ! command_exists error; then
  error() { simple_log error "$@"; }
fi
if ! command_exists warn; then
  warn() { simple_log warning "$@"; }
fi
if ! command_exists warning; then
  warning() { simple_log warning "$@"; }
fi
if ! command_exists notice; then
  notice() { simple_log notice "$@"; }
fi
if ! command_exists info_log; then
  info_log() { simple_log info "$@"; }
fi
if ! command_exists debug_log; then
  debug_log() {
    if [[ -n ${DEBUG:-} ]]; then
      simple_log debug "$@"
    fi
  }
fi
if ! command_exists chomp; then
  chomp() { printf "%s" "${1/"$'\n'"/}"; }
fi
