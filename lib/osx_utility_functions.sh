#!/usr/bin/env bash
export OSX_UTILITY_FUNCTIONS_LOADED=1
command_exists() {
  command -v "$@" >/dev/null 2>&1
}

brew_app_directory() {
  if command_exists brew; then
    if [[ $# -eq 0 ]]; then
      return 1
    else
      if command_exists readlink; then
        readlink -f "$(brew --prefix "$@")"
      else
        for app in "$@"; do
          echo "$(brew --cellar "${app}")/$(brew info --json "${app}" | jq -r '.[0].installed[0].version')"
        done
      fi
    fi
  fi
}
