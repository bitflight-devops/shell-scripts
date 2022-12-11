#!/bin/bash
# shellcheck disable=SC2248,SC2292
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")"  > /dev/null 2>&1 && pwd)"
ZSH_AVAILABLE=0

root_available() {
  local -r user="$(id -un 2> /dev/null || true)"
  if [[ ${user} != 'root' ]]; then
    if command_exists sudo; then
      if [[ $(SUDO_ASKPASS="${BIN_FALSE[*]}" sudo -A sh -c 'whoami;whoami' 2>&1 | wc -l) -eq 2 ]]; then
        echo "sudo"
        return 0
      elif groups "${user}" | grep -q '(^|\b)(sudo|wheel)(\b|$)' && [[ -n ${INTERACTIVE:-} ]]; then
        echo "sudo"
        return 0
      else
        echo ""
        return 1
      fi
    else
      # not root, and don't have sudo
      echo ""
      return 1
    fi
  else
    echo ""
    return 0
  fi
}

run_as_root() {
  local sd="$(root_available)"
  local -r rv="$?"
  if [[ ${rv} -eq 0 ]] && [[ ${sd} == '' ]]; then
     "${@}"
  elif [[ ${rv} -eq 0 ]] && [[ ${sd} == 'sudo' ]]; then
     sudo "${@}"
  else
    printf 'This command needs the ability to run other commands as root.\nWe are unable to find "sudo" available to make this happen.\n\n'
    exit 1
  fi
}

if ! command -v zsh > /dev/null 2>&1; then
  echo "zsh is not installed, installing it now."
  curl -s -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key | sudo apt-key add - || true
  # wget -qO - https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key | sudo apt-key add -
  run_as_root apt-get update -qq -y && run_as_root apt-get install -qq -y zsh > /dev/null 2>&1 && zsh --version && ZSH_AVAILABLE=1
else
  ZSH_AVAILABLE=1
fi

## tests/bootstrap-bash-test.sh

SUM_OF_SOURCED_FILES=12
echo "DIR: ${DIR}"
getSourceFilesViaSource() {
  source "${DIR}/../lib/bootstrap.sh"
}
outputViaSource() {
  cat << EOF
# INFO: Loading libraries...
[ INFO] bootstrap_exec:  ★ Libraries loaded
         -> color_and_emoji_variables
         -> elasticbeanstalk_functions
         -> general_utility_functions
         -> github_core_functions
         -> log_functions
         -> osx_utility_functions
         -> remote_utility_functions
         -> string_functions
         -> system_functions
         -> trace_functions
         -> yaml_functions
         -> java_functions
EOF
}

getSourceFilesViaExecution() {
  local useshell="${1:-bash}"
  shift
  ${useshell} -- "${DIR}/../lib/bootstrap.sh" "$@"
}

testBootstrapScriptReadable() {
  assertTrue '' "[ -r \"${DIR}/../lib/bootstrap.sh\" ]"
}

testGenerateOutputViaSource() {
  unset BFD_REPOSITORY
  unset SCRIPTS_LIB_DIR
  ( getSourceFilesViaSource > "${stdoutF}" 2> "${stderrF}")
  rtrn=$?

  # This test will fail because a non-zero return code was provided.
  assertTrue "the command exited with an error" ${rtrn}

  # Show the command output if the command provided a non-zero return code.
  [ ${rtrn} -eq 0 ] || showOutput

  # This test will pass because the grepped output matches.
  grep -q "$(outputViaSource)" "${stdoutF}"
  assertTrue 'output matches expected output' $?

  # This test will pass because the grepped output count matches.
  lineCount=$(grep -o "\-> " "${stdoutF}" | wc -l | tr -d ' ')
  assertEquals 'sourced files should be 12' 12 "${lineCount}" || showOutput

  return 0
}

testGenerateOutputViaExecution() {
  unset BFD_REPOSITORY
  unset SCRIPTS_LIB_DIR

  ( getSourceFilesViaExecution bash > "${stdoutF}" 2> "${stderrF}")
  rtrn=$?

  # This test will fail because a non-zero return code was provided.
  assertTrue "the command exited with an error" ${rtrn}

  # Show the command output if the command provided a non-zero return code.
  [ ${rtrn} -eq 0 ] || showOutput

  # This test will pass because the grepped output matches.
  grep -q "source '" "${stdoutF}"
  assertTrue 'list of files to source missing' $?

  # Check that the output includes all the expected files.
  sourceLineCount=$(grep -c "source '" "${stdoutF}")
  assertEquals 'count of sourced files via bash matches sum of sourced files in folder' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}" || showOutput

  ( getSourceFilesViaExecution "bash" "--silent" > "${stdoutF}" 2> "${stderrF}")
  rtrn=$?

  # This test will fail because a non-zero return code was provided.
  assertTrue "the command exited with an error" ${rtrn}

  # Show the command output if the command provided a non-zero return code.
  [ ${rtrn} -eq 0 ] || showOutput

  # Check that the output includes all the expected files.
  sourceLineCount=$(grep -c "source '" "${stdoutF}")
  assertEquals 'count of sourced files via bash using "--silent" flag matches sum of sourced files in folder' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}"

  assertEquals "the command leaked exported variables to the environment" \
    "$(env | grep -c -E '^(BFD_REPOSITORY|SCRIPTS_LIB_DIR)=')" 0

  assertNull "the command leaks the variable BFD_REPOSITORY to the shell" \
    "${BFD_REPOSITORY}"

  assertNull "the command leaks the variable SCRIPTS_LIB_DIR to the shell" \
    "${SCRIPTS_LIB_DIR}"

  if [[ ${ZSH_AVAILABLE} -eq 1 ]]; then
    (getSourceFilesViaExecution "zsh" "--silent" > "${stdoutF}" 2> "${stderrF}")
    rtrn=$?

    # This test will fail because a non-zero return code was provided.
    assertTrue "the command exited with an error" ${rtrn}

    # Show the command output if the command provided a non-zero return code.
    [ ${rtrn} -eq 0 ] || showOutput

    # Check that the output includes all the expected files.
    sourceLineCount=$(grep -c "source '" "${stdoutF}")
    assertEquals 'count of sourced files via zsh matches sum of sourced files in folder' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}" || showOutput

  fi
  return 0
}

testGenerateOutputViaExecution_IndividualLibrary() {
  unset BFD_REPOSITORY
  unset SCRIPTS_LIB_DIR
  declare -a AVAILABLE_LIBRARIES=(
    "color_and_emoji_variables"
    "elasticbeanstalk_functions"
    "general_utility_functions"
    "github_core_functions"
    "log_functions"
    "osx_utility_functions"
    "remote_utility_functions"
    "string_functions"
    "system_functions"
    "trace_functions"
    "yaml_functions"
    "java_functions"
  )
  for useshell in bash zsh; do
    for library in "${AVAILABLE_LIBRARIES[@]}"; do
      ( getSourceFilesViaExecution "${useshell}" "${library}" > "${stdoutF}" 2> "${stderrF}")
      rtrn=$?

      # This test will fail because a non-zero return code was provided.
      assertTrue "the command exited with an error" ${rtrn}

      # Show the command output if the command provided a non-zero return code.
      [ ${rtrn} -eq 0 ] || showOutput

      # This test will pass because the grepped output matches.
      grep -q  "source '" "${stdoutF}"
      assertTrue 'Output missing' $?

      # This test will pass because the grepped output count matches.
      lineCount=$(grep -c "source '" "${stdoutF}")
      assertEquals 'list of source files is only one' "${lineCount}" 1
      libraryIncluded=$(grep -c -E "^source .*${library}" "${stdoutF}")
      assertEquals 'should include the selected library' "${libraryIncluded}" 1

    done
  done

  return 0
}

showOutput() {
  # shellcheck disable=SC2166
  if [ -n "${stdoutF}" -a -s "${stdoutF}" ]; then
    echo '>>> STDOUT' >&2
    cat "${stdoutF}" >&2
    echo '<<< STDOUT' >&2
  fi
  # shellcheck disable=SC2166
  if [ -n "${stderrF}" -a -s "${stderrF}" ]; then
    echo '>>> STDERR' >&2
    cat "${stderrF}" >&2
    echo '<<< STDERR' >&2
  fi
}

oneTimeSetUp() {
  # Define global variables for command output.
  stdoutF="${SHUNIT_TMPDIR}/stdout"
  stderrF="${SHUNIT_TMPDIR}/stderr"
  # the number of files sourced by bootstrap.sh
  SUM_OF_SOURCED_FILES=12
}

setUp() {
  # Truncate the output files.
  cp /dev/null "${stdoutF}"
  cp /dev/null "${stderrF}"
}

# Load shUnit2.
. "${DIR}/shunit2/shunit2"
