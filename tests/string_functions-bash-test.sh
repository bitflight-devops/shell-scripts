#!/bin/bash
DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
export SCRIPTS_LIB_DIR="$(cd "${DIR}/../lib" && pwd -P)"
if [[ ! -d ${SCRIPTS_LIB_DIR} ]]; then
  echo "ERROR: SCRIPTS_LIB_DIR does not exist"
  exit 1
fi
export BFD_REPOSITORY="${SCRIPTS_LIB_DIR%/lib}"

# Test Constants
COLOR_BG_BLUE=$'\e[1;44m'
COLOR_BG_MAGENTA=$'\e[1;45m'
export COLOR_GREEN=$'\e[0;32m'
COLOR_YELLOW=$'\e[0;33m'
COLOR_RESET=$'\e[0m'

TEST_INPUT_STRING_COLORIZED="${COLOR_BG_BLUE}This is a test String${COLOR_RESET}"
TEST_INPUT_PADDED_STRING_COLORIZED="  ${COLOR_BG_BLUE}   This is a test String  ${COLOR_RESET}  "
TEST_INPUT_STRING='This is a test String'
TEST_INPUT_PADDED_STRING='  This is a test String  '
TEST_INPUT_DASH_PADDED_STRING='--This is a test String--'
TEST_INPUT_OVERLY_SPACED_STRING='This   is   a   test      String


'

TEST_OUTPUT_STRING='This is a test String'
TEST_OUTPUT_TITLE_CASE_STRING='This Is A Test String'
TEST_OUTPUT_STRING_UPPERCASE='THIS IS A TEST STRING'
TEST_OUTPUT_STRING_LOWERCASE='this is a test string'

testIscolorcodeOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    if iscolorcode $'\e[0;32m'; then
      echo $'\e[0;32m'"green"$'\e[0m'
    fi
    iscolorcode $'\e[0;32m' > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?

  assertEquals "the command exited with an error" "0" "${rtrn}"
  # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals "iscolorcode $'\e[0;32m'output$'\e[0m' does not match expected output" "" "$(cat "${stdoutF}")"
  return 0
}

testColorcodeOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    colorcode "COLOR_BG_BLUE" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'colorcode output does not match expected output' "${COLOR_BG_BLUE}" "$(cat "${stdoutF}")"

  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    colorcode "COLOR_BG_BLUE_nonexistant" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'colorcode output does not match expected output' "" "$(cat "${stdoutF}")"

  return 0
}
testUppercaseOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    uppercase "${TEST_INPUT_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'uppercase output does not match expected output' "${TEST_OUTPUT_STRING_UPPERCASE}" "$(cat "${stdoutF}")"
  return 0
}
testLowercaseOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    lowercase "${TEST_INPUT_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'lowercase output does not match expected output' "${TEST_OUTPUT_STRING_LOWERCASE}" "$(cat "${stdoutF}")"
  return 0
}
testTitlecaseOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    titlecase "${TEST_INPUT_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'titlecase output does not match expected output' "${TEST_OUTPUT_TITLE_CASE_STRING}" "$(cat "${stdoutF}")"
  return 0
}
testSquash_SpacesOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    squash_spaces "${TEST_INPUT_OVERLY_SPACED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'squash_spaces output does not match expected output' "${TEST_OUTPUT_STRING}" "$(cat "${stdoutF}")"
  return 0
}
testTrim_DashesOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    trim_dash "${TEST_INPUT_DASH_PADDED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'trim_dash output does not match expected output' "${TEST_OUTPUT_STRING}" "$(cat "${stdoutF}")"
  return 0
}
testTrimOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    trim "${TEST_INPUT_PADDED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'trim output does not match expected output' "${TEST_OUTPUT_STRING}" "$(cat "${stdoutF}")"
  return 0
}
testTrim_with_colorOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    trim "${TEST_INPUT_PADDED_STRING_COLORIZED}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'trim output does not match expected output' "${TEST_INPUT_STRING_COLORIZED}" "$(cat "${stdoutF}")"
  return 0
}
testStripcolorOutput() {
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    stripcolor "${TEST_INPUT_STRING_COLORIZED}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'stripcolor output does not match expected output' "${TEST_OUTPUT_STRING}" "$(cat "${stdoutF}")"
  return 0
}
testSquash_OutputOutput() {
  # With non-empty string
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    squash_output echo "${TEST_INPUT_DASH_PADDED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited with an error" "0" "${rtrn}" # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'squash_output output does not match expected output' "" "$(cat "${stdoutF}")"
  return 0
}
testEmptyOutput() {
  # With non-empty string
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    empty "${TEST_INPUT_DASH_PADDED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command 'empty' returned 0, but should have been 1" "1" "${rtrn}"
  # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 1 ]] || showOutput
  assertEquals 'empty output does not match expected output' "false" "$(cat "${stdoutF}")"

  # With Empty String
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    empty " " > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command returned 1, but should have been 0" "0" "${rtrn}"
  # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'empty output does not match expected output' "true" "$(cat "${stdoutF}")"

  return 0
}
testIsEmptyStringOutput() {
  # With non-empty string
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    isEmptyString "${TEST_INPUT_DASH_PADDED_STRING}" > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command returned 0 'true', but should have been 1 'false'" "1" "${rtrn}"
  # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'isEmptyString output does not match expected output' "" "$(cat "${stdoutF}")"

  # With Empty String
  ( 
    source "${SCRIPTS_LIB_DIR}/string_functions.sh"
    isEmptyString " " > "${stdoutF}" 2> "${stderrF}"
  )
  rtrn=$?
  assertEquals "the command exited false, but shuld have been true" "0" "${rtrn}"
  # Show the command output if the command provided a non-zero return code.
  [[ ${rtrn} -eq 0 ]] || showOutput
  assertEquals 'isEmptyString output does not match expected output' "" "$(cat "${stdoutF}")"

  return 0
}

showOutput() {
  # shellcheck disable=SC2166,SC2292
  if [ -n "${stdoutF}" -a -s "${stdoutF}" ]; then
    echo '>>> STDOUT' >&2
    cat "${stdoutF}" >&2
    echo '<<< STDOUT' >&2
  fi
  # shellcheck disable=SC2166,SC2292
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
}

setUp() {
  # Truncate the output files.
  cp /dev/null "${stdoutF}"
  cp /dev/null "${stderrF}"
}

# Load and run shUnit2.
# shellcheck disable=SC1091
# Load shUnit2.
. "${DIR}/shunit2/shunit2"
