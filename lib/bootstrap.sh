#!/usr/bin/env bash

function load_libraries() {
  declare -a LIBRARIES=("$@")
  if [[ -n ${BFD_REPOSITORY} ]] && [[ -x ${BFD_REPOSITORY} ]]; then

    for library in "${LIBRARIES[@]}"; do
      if [[ -f "${BFD_REPOSITORY%/}/lib/${library}.sh" ]]; then
        echo "source '${BFD_REPOSITORY%/}/lib/${library}.sh'"
      else
        echo "Library ${library} not found" >&2
      fi
    done
  else
    echo "BFD_REPOSITORY not set" >&2

  fi
}

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
)
if [[ $# -eq 0 ]]; then
  echo "Loading libraries..."
  load_libraries "${AVAILABLE_LIBRARIES[@]}" && eval "$(load_libraries "${AVAILABLE_LIBRARIES[@]}")"
else
  load_libraries "$@" && eval "$(load_libraries "$@")"
fi
