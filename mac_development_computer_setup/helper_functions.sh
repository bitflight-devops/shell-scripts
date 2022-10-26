#!/usr/bin/env bash
# BFD == BitFlight Devops
SHELL_SCRIPTS_OWNER="bitflight-devops"
SHELL_SCRIPTS_REPOSITORY_NAME="shell-scripts"
SHELL_SCRIPTS_GITHUB_REPOSITORY="${SHELL_SCRIPTS_OWNER}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
: "${BFD_REPOSITORY:="${HOME}/.local/${SHELL_SCRIPTS_GITHUB_REPOSITORY}"}"
## Create helper shell functions
command_exists() {
  command -v "$@" > /dev/null 2>&1
}

reshim() {
  # Reshim ASDF if it is installed
  if command_exists asdf; then
    asdf reshim
  fi
  # Reshim jenv if it is installed
  if command_exists jenv; then
    jenv reshim
  fi
}

slurp() {
  if [[ -p /dev/stdin ]]; then
    cat -
  fi
  if [[ "$#" -ne 0 ]]; then
    echo "$@"
  fi
}

get_tool_info() {
  brew info --json "$1" | jq -r '.[] | "brew_apps+=(\""+(.name)+"\") # "+(.desc)'
}

brew_tap_individually() {
  NONINTERACTIVE=1 xargs -t -P1 -I'{}' -n1 bash -c "brew tap -q --repair ${*} '{}' || true"
}

brew_install_individually() {
  NONINTERACTIVE=1 xargs -t -P1 -I'{}' -n1 bash -c "brew install -q -f ${*} '{}' || true"
}

brew_info_individually() {
  info_func="$(declare -f get_tool_info)"
  NONINTERACTIVE=1 xargs -P5 -I'{}' -n1 bash -c "${info_func};get_tool_info '{}' || true"
}

brew_tap_all() {
  IFS=" " read -r -a wordlist <<< "$(slurp "$@")"
  brew_tap_individually <<< "${wordlist[*]}"
}

brew_install_all() {
  # Install all packages supplied via stdin, and as arguments
  # Attempt to install all packages, even if some fail
  IFS=" " read -r -a wordlist <<< "$(slurp "$@")"
  if [[ "${#wordlist[@]}" -eq 0 ]]; then
    echo "No formulae supplied to brew_install_all" >&2
    return 1
  fi
  if grep -q -- "--cask" <<< "${wordlist[*]}"; then
    iscask="--cask"
    formula=("${wordlist[@]/"${iscask}"/}")
    echo "Installing ${wordlist[*]} as casks"
  else
    echo "Installing ${wordlist[*]}"
  fi
  # shellcheck disable=SC2248
  NONINTERACTIVE=1 brew install -f ${iscask-} "${wordlist[@]}" || brew_install_individually ${iscask-} <<< "${wordlist[*]}"
}

add_helper_functions_to_profile() {
  local this_script="${BFD_REPOSITORY}/mac_development_computer_setup/helper_functions.sh"
  mkdir -p "$(dirname "${this_script}")" || return 1

  # Add helper functions to profile
  local source_line="[ -f \"${this_script}\" ] && eval (<\"${this_script}\")"
  if ! grep -q "${this_script}" ~/.zshrc; then
    echo "Adding helper functions to ~/.zshrc"
    echo "${source_line}" >> ~/.zshrc
  fi
    if ! grep -q "${this_script}" ~/.bashrc; then
    echo "Adding helper functions to ~/.bashrc"
    echo "${source_line}" >> ~/.bashrc
  fi
}
