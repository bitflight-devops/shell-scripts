#!/bin/bash
# shellcheck disable=SC2248,SC2292
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")"  > /dev/null 2>&1 && pwd)"

## tests/bootstrap-bash-test.sh

SUM_OF_SOURCED_FILES=12

getSourceFilesViaSource() {
  . "${DIR}/../lib/bootstrap.sh"
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
  grep -E '^source ' "${stdoutF}" > /dev/null
  assertTrue 'STDOUT message missing' $?

  # This test will pass because the grepped output count matches.
  lineCount=$(grep -o -E "^source " "${stdoutF}" | wc -l | tr -d ' ')
  assertEquals 'STDOUT list of source files' 12 "${lineCount}"

  # # This test will fail because the grepped output doesn't match.
  # grep 'ST[andar]DERR[or]' "${stderrF}" >/dev/null
  # assertTrue 'STDERR message missing' $?

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
  grep -E '^source ' "${stdoutF}" > /dev/null
  assertTrue 'STDOUT list of files to source missing' $?


  lineCount=$(wc -l <<< "${stdoutF}" | tr -d ' ')

  # Check that the output includes all the expected files.
  sourceLineCount=$(grep -c -E "^source " "${stdoutF}")
  assertEquals 'STDOUT list of sourced files via bash' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}"
  assertEquals "STDOUT includes more lines than the list of sources" "${sourceLineCount}" "${lineCount}"

  # # This test will fail because the grepped output doesn't match.
  # grep 'ST[andar]DERR[or]' "${stderrF}" >/dev/null
  # assertTrue 'STDERR message missing' $?
  ( getSourceFilesViaExecution "bash" "--silent" > "${stdoutF}" 2> "${stderrF}")
  rtrn=$?

  # This test will fail because a non-zero return code was provided.
  assertTrue "the command exited with an error" ${rtrn}

  # Show the command output if the command provided a non-zero return code.
  [ ${rtrn} -eq 0 ] || showOutput

  # Check that the output includes all the expected files.
  sourceLineCount=$(grep -c -E "^source " "${stdoutF}")
  assertEquals 'STDOUT list of sourced files via bash' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}"

  assertEquals "the command leaked exported variables to the environment" \
    "$(env | grep -c -E '^(BFD_REPOSITORY|SCRIPTS_LIB_DIR)=')" 0

  assertNull "the command leaks the variable BFD_REPOSITORY to the shell" \
    "${BFD_REPOSITORY}"

  assertNull "the command leaks the variable SCRIPTS_LIB_DIR to the shell" \
    "${SCRIPTS_LIB_DIR}"

  if command -v zsh > /dev/null 2>&1; then
    (getSourceFilesViaExecution "zsh" "--silent" > "${stdoutF}" 2> "${stderrF}")
    rtrn=$?

    # This test will fail because a non-zero return code was provided.
    assertTrue "the command exited with an error" ${rtrn}

    # Show the command output if the command provided a non-zero return code.
    [ ${rtrn} -eq 0 ] || showOutput

    # Check that the output includes all the expected files.
    sourceLineCount=$(grep -c -E "^source " "${stdoutF}")
    assertEquals 'STDOUT list of sourced files via zsh' ${SUM_OF_SOURCED_FILES} "${sourceLineCount}"

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
      grep -E '^source ' "${stdoutF}" > /dev/null
      assertTrue 'STDOUT message missing' $?

      # This test will pass because the grepped output count matches.
      lineCount=$(grep -c -E "^source " "${stdoutF}")
      assertEquals 'STDOUT list of source files'  "[ ${lineCount} -lt ${SUM_OF_SOURCED_FILES} ]"
      libraryIncluded=$(grep -c -E "^source .*${library}" "${stdoutF}")
      assertEquals 'STDOUT should include the selected library'  "[ ${libraryIncluded} -eq 1 ]"
      # # This test will fail because the grepped output doesn't match.
      # grep 'ST[andar]DERR[or]' "${stderrF}" >/dev/null
      # assertTrue 'STDERR message missing' $?
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
