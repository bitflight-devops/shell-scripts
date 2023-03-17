#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2296,SC2162

# Posix compliant way to check if a command exists,
# works in bash and zsh, and is used in this script
command_exists() { command -v "${@}" > /dev/null 2>&1; }

# I'm avoiding subshells in bash and zsh for performance reasons

# Benchmark here in bash:
# hyperfine --shell='bash -norc --noprofile' -n 'subshell' '\shopt -s lastpipe 2> /dev/null;returns_string() { echo "string1"; };output=$(returns_string);echo ${output};' -n 'pipe' '\shopt -s lastpipe 2> /dev/null;returns_string() { echo "string2"; };returns_string | read -r output;echo ${output};' 2>/dev/null
# Benchmark 1: subshell
#   Time (mean ± σ):       0.9 ms ±   2.3 ms    [User: 0.4 ms, System: 0.5 ms]
#   Range (min … max):     0.4 ms …  37.7 ms    501 runs
#
# Benchmark 2: pipe
#   Time (mean ± σ):       0.9 ms ±   1.4 ms    [User: 0.4 ms, System: 0.6 ms]
#   Range (min … max):     0.1 ms …  24.4 ms    478 runs
#
# Summary
#   'pipe' ran
#     1.09 ± 3.25 times faster than 'subshell'

## Here in zsh:
# hyperfine --shell='zsh -fd' -n 'subshell' '\shopt -s lastpipe 2> /dev/null;returns_string() { echo "string1"; };output=$(returns_string);echo ${output};' -n 'pipe' '\shopt -s lastpipe 2> /dev/null;returns_string() { echo "string2"; };returns_string | read -r output;echo ${output};' 2>/dev/null
# Benchmark 1: subshell
#   Time (mean ± σ):       2.2 ms ±   2.1 ms    [User: 0.8 ms, System: 1.8 ms]
#   Range (min … max):     1.2 ms …  32.3 ms    242 runs
#
# Benchmark 2: pipe
#   Time (mean ± σ):       1.7 ms ±   0.5 ms    [User: 0.7 ms, System: 1.7 ms]
#   Range (min … max):     1.1 ms …   4.3 ms    258 runs
#
# Summary
#   'pipe' ran
#     1.29 ± 1.26 times faster than 'subshell'
\shopt -s lastpipe 2> /dev/null
reenable_lastpipe() { \shopt -u lastpipe 2> /dev/null; }
trap reenable_lastpipe EXIT

# a newline character
newline=$'\n'

# Some colors for pretty printing
cyan=$'\e[36m'
grey=$'\e[90m'
yellow=$'\e[33m'
color_reset=$'\e[0m'

# The directory to store benchmark reports
BENCHMARK_REPORT_DIR="${BENCHMARK_REPORT_DIR:-${HOME}/benchmarks}"

# Pretty print a KV pair as arguments
command_exists print_pair || print_pair() { printf '%s%s%s:%s %s%s\n' "${cyan}" "${1}" "${grey}" "${yellow}" "${2}" "${color_reset}"; }

# Pretty print a colon seperated KV pair from std input
command_exists pipe_pair || pipe_pair() { sed -E 's/^([[:alnum:]_ "'"'"'-]+):(.*)$/'$'\e[36m''\1:'$'\e[33m''\2'$'\e[0m''\n/'; }

# Indent a newline separated string
command_exists indent_newline || indent_newline() { fold -w60 -s | pr -to "${1:-17}" | sed '1s/^ *//'; }

if ! command_exists logformat_log; then
  # create a templated timestamped formatted log message
  logformat_log() {
    local l_level="${1}"
    shift
    local msg="$(pipe_pair <<< "${*//\\n/${newline}}")"
    date '+%H:%M:%S' | read -r l_ts
    printf '%8.8s [%5.5s] %s\n' "${l_ts}" "${l_level}" "${msg}" | indent_newline
  }
fi
# log a message to stdout
command_exists info_log || info_log() { logformat_log "INFO" "${*}"; }
# log a message to stderr
command_exists error_log || error_log() { logformat_log "ERROR" "${*}" 1>&2; }

# Check that the benchmark utility is installed
if ! command_exists hyperfine && command_exists brew; then
  info_log "Installing: hyperfine"
  if brew install hyperfine > /dev/null 2>&1; then
    info_log "hyperfine installed"
  else
    error_log "hyperfine failed to automatically install using 'brew install hyperfine'"
  fi
fi

# Announce how to install the benchmark utility if it's not installed
if ! command_exists hyperfine; then
  printf 'hyperfine is not installed, please install it with your package manager\n'
  printf 'https://github.com/sharkdp/hyperfine#installation\n\n'
  exit 1
fi

# track each run of this script with an incrementing run id
run_id() {
  local BENCHMARK_REPORT_DIR="${1:-${HOME}/benchmarks}"
  [[ -d ${BENCHMARK_REPORT_DIR}   ]] || mkdir -p "${BENCHMARK_REPORT_DIR}"
  local id_file_path="${BENCHMARK_REPORT_DIR}/.runId"
  local runId
  if [[ -f "${id_file_path}"   ]]; then
    read -r runId < "${id_file_path}" || true
  fi
  # If the file is empty, set it to 0
  : "${runId:=0}"
  # Increment the run id
  ((runId += 1))
  # Write the new run id to the file, and stdout
  printf '%s' "${runId}" | tee "${BENCHMARK_REPORT_DIR}/.runId"
}

# Print first line of the shell version output
shelli() { "${1}" --version 2>&1 | head -n 1; }

# clean, as in, no profile, or rc files to slow down startup times
clean_shell_command() {
    local sn="$1"
    case "${sn}" in
      *"bash") printf '%s' "${sn} --norc --noprofile"  ;;
      *"zsh") printf '%s' "${sn} -fd"  ;;
      *) printf '%s' "${sn}"  ;;
  esac
}

# Get the shell name and version for labeling the report
shell_command_report_name() {
  local sn="${1%% *}"
  local runId="$2"
  local run_cmds="$3"
  local version
  local run_hash
  md5 -s -q <<< "${run_cmds}" | read -r run_hash
  case "${sn}" in
    *"bash") ${sn} -c 'echo ${BASH_VERSION}' | read -r version ;;
    *"zsh") ${sn} -c 'echo ${ZSH_VERSION}' | read -r version ;;
    *) exit 1  ;;
  esac
  loc
    printf '%s' "${sn##*/}-${version}-${run_hash}-run${runId}"
}

  test_with_shell() {
    local commands_to_test="$1"
    local sc="${2}"
    local test_success="${3:-true}"
    if [[ -z ${sc+x}   ]]; then
      printf 'No shell provided to test_with_shell()\n'
      return 1
  fi

    info_log "Shell command: ${sc}"

    local prefix
    local test_template
    if [[ "${test_success}" != "true"   ]]; then
      prefix="ret0-"
      test_template='ef() { return 0; }; {cmd} ef >/dev/null 2>&1'
  else
      # Allow Failures
      hf_params+=("-i")
      prefix="ret1-"
      test_template='unset -f ef;{cmd} ef >/dev/null 2>&1'
  fi
    local report_name
    shell_command_report_name "${sc}" "${RUN_ID:-0}" "${commands_to_test}" | read -r report_name
    report_name="${prefix}${report_name}"
    local hf_params=(
      "--export-json=${BENCHMARK_REPORT_DIR}/${report_name}.json"
      "--warmup=10"
      "--shell=${sc}"
  )
    if [[ -n ${DEBUG+x} ]]; then
      if [[ ${DEBUG} == "stdout"   ]]; then
        hf_params+=("--show-output")
    else
        hf_params+=("--output=${BENCHMARK_REPORT_DIR}/${report_name}-output.txt")
    fi
  fi


    local test_name_template="${report_name} {cmd}"
    info_log "${benchmark_title}"
    hyperfine \
    "${hf_params[@]}" \
      -L "cmd" "${commands_to_test}" \
      -n "${test_name_template}" \
      "${test_template}" \
    2>> "${BENCHMARK_REPORT_DIR}/hyperfine.error.log" || { error_log "hyperfine failed"; tail "${BENCHMARK_REPORT_DIR}/hyperfine.error.log"; return 1; }
}

main() {
  if [[ ${#@} -lt 2 ]]; then
    info_log "Arg 0: ${0}"
    info_log "Arg 1: commands_to_test: a comma seperated list of commands to test, e.g.\ncommand -v,type,which,whence -v"
    info_log "Arg 2: shell_command: which shell to execuse the tests within: e.g.\n/bin/bash\n/usr/local/bin/bash\n/bin/zsh\n/usr/local/bin/zsh\nwith full path to the shell executable if it's not in your PATH"
    info_log "Usage: ${0} 'command1,command2,command3' 'shell_command' [true|false] [benchmark_title]" "$0"
    if [[ ${#@} -eq 0 ]]; then
      return 0
    else
      error_log "${*} <-- too few arguments ${#@}"
      error_log "You must provide at least two arguments"
      return 1
    fi
  fi
  # Set the commands to test, as comma seperated values
  local commands_to_test="$1"
  # Set the shell to test in
  local shell_command="$2"
  # Set the expected test result, true or false
  local test_success="${3:-true}"
  # Set Title of benchmark run
  local benchmark_title="${4:-"Benchmarking '${commands_to_test}', with shell '${shell_command}'"}"
  # Set the benchmark report directory to the value of the environment variable
  # BENCHMARK_REPORT_DIR, or to ${HOME}/benchmarks if it's not set
  local BENCHMARK_REPORT_DIR="${BENCHMARK_REPORT_DIR:-${HOME}/benchmarks}"
  [[ -d ${BENCHMARK_REPORT_DIR}   ]] || mkdir -p "${BENCHMARK_REPORT_DIR}"

  # Read in the output of run_id() and set it to RUN_ID without using a subshell
  # works in bash and zsh

  uname -v | read -r SYSTEM_INFO
  shelli "${shell_command}" | read -r "SHELL_INFO"
  info_log "This is run number: ${RUN_ID}\nSystem info: ${SYSTEM_INFO}\nShell Info: ${SHELL_INFO}\nBenchmarking functions to check if a command or function exists already\n"
  info_log "Run Title: ${benchmark_title}"

  # Read in the output of clean_shell_command() and set it to CLEAN_SHELL_COMMAND
  # without using a subshell
  clean_shell_command "${shell_command}" | read -r CLEAN_SHELL_COMMAND
  test_with_shell "${commands_to_test}" "${CLEAN_SHELL_COMMAND}" "${test_success}"
}

if [[ $1 == 'bash' ]]; then
  BASH_TESTS_ONLY=true
elif [[ $1 == 'zsh' ]]; then
  ZSH_TESTS_ONLY=true
fi

check_if_command="type,command -v,which"

check_if_function='type ef && ! type -p ef,declare -Ff ef,typeset -f ef'

if [[ -n ${ZSH_TESTS_ONLY+x} ]]; then
  check_if_function="${check_if_function},functions ef"
  check_if_command="${check_if_command},whence -f ef"
fi

# Compgen is a bash builtin, not a zsh builtin
# so for zsh it requires this to be run first to load the bashcompinit function:
# ```
# autoload bashcompinit
# bashcompinit
# ```
# but it still needs to be piped to grep to get the same output as bash
## -n "${report_name} compgen" "ef() { return 0; };compgen -A function | grep -E '^ef$'"

# Find the path to the brew installed zsh and bash
brew --prefix zsh | read -r BREW_ZSH_PREFIX
brew --prefix bash | read -r BREW_BASH_PREFIX
  run_id "${BENCHMARK_REPORT_DIR:-}" | read -r RUN_ID
export RUN_ID
set -ex
if [[ -z ${ZSH_TESTS_ONLY+x} ]]; then
  info_log "Check if command exists in bash, when we know it does"
  main "${check_if_command}" '/bin/bash'
  main "${check_if_command}" "${BREW_BASH_PREFIX}/bin/bash"
  info_log "Check if command exists in bash, when we know it doesn't"
  main  "${check_if_command}" '/bin/bash' "false"
  main  "${check_if_command}" "${BREW_BASH_PREFIX}/bin/bash" "false"
    info_log "Check if function exists in bash, when we know it does"
  main "${check_if_function}" '/bin/bash'
  main "${check_if_function}" "${BREW_BASH_PREFIX}/bin/bash"
  info_log "Check if function exists in bash, when we know it doesn't"
  main  "${check_if_function}" '/bin/bash' "false"
  main  "${check_if_function}" "${BREW_BASH_PREFIX}/bin/bash" "false"
fi
if [[ -z ${BASH_TESTS_ONLY+x} ]]; then
  info_log "Check if command exists in zsh, when we know it does"
  main "${check_if_command}" '/bin/zsh'
  main "${check_if_command}" "${BREW_ZSH_PREFIX}/bin/zsh"
  info_log "Check if command exists in zsh, when we know it doesn't"
  main  "${check_if_command}" '/bin/zsh' "false"
  main  "${check_if_command}" "${BREW_ZSH_PREFIX}/bin/zsh" "false"
  info_log "Check if function exists in zsh, when we know it does"
  main "${check_if_function}" '/bin/zsh'
  main "${check_if_function}" "${BREW_ZSH_PREFIX}/bin/zsh"
  info_log "Check if function exists in zsh, when we know it doesn't"
  main  "${check_if_function}" '/bin/zsh' "false"
  main  "${check_if_function}" "${BREW_ZSH_PREFIX}/bin/zsh" "false"

  check_if_command="${check_if_command},whence -f ef"
  check_if_function="${check_if_function},functions ef"

fi
