#!/usr/bin/env bash

# Download the latest version of the script from the following URL:
# https://raw.githubusercontent.com/bitflight-devops/scripts/master/install.sh

set -eu

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]; then
  abort "Cannot run force-interactive mode in CI."
fi

BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

SHELL_SCRIPTS_GITHUB_REPOSITORY="bitflight-devops/shell-scripts"
BIN_DIR="${HOME}/.bin"
DEFAULT_INSTALL_DIR="${HOME}/.config/${SHELL_SCRIPTS_GITHUB_REPOSITORY}"

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")"
}

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]; then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# First check OS.
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]; then
  SHELL_SCRIPTS_LINUX=1
elif [[ "${OS}" != "Darwin" ]]; then
  abort "shell-scripts is only supported on macOS and Linux."
fi

if [[ -z "${SHELL_SCRIPTS_LINUX-}" ]]; then
  UNAME_MACHINE="$(/usr/bin/uname -m)"

  if [[ "${UNAME_MACHINE}" == "arm64" ]]; then
    # On ARM macOS, this script installs to /opt/homebrew only
    HOMEBREW_PREFIX="/opt/homebrew"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
  else
    # On Intel macOS, this script installs to /usr/local only
    HOMEBREW_PREFIX="/usr/local"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  fi
  HOMEBREW_CACHE="${HOME}/Library/Caches/Homebrew"

  STAT_PRINTF=("stat" "-f")
  PERMISSION_FORMAT="%A"
  CHOWN=("/usr/sbin/chown")
  CHGRP=("/usr/bin/chgrp")
  GROUP="admin"
  TOUCH=("/usr/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "root" -g "wheel" -m "0755")
else
  UNAME_MACHINE="$(uname -m)"

  # On Linux, it installs to /home/linuxbrew/.linuxbrew if you have sudo access
  # and ~/.linuxbrew (which is unsupported) if run interactively.
  HOMEBREW_PREFIX_DEFAULT="/home/linuxbrew/.linuxbrew"
  HOMEBREW_CACHE="${HOME}/.cache/Homebrew"

  STAT_PRINTF=("stat" "--printf")
  PERMISSION_FORMAT="%a"
  CHOWN=("/bin/chown")
  CHGRP=("/bin/chgrp")
  GROUP="$(id -gn)"
  TOUCH=("/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "${USER}" -g "${GROUP}" -m "0755")
fi
CHMOD=("/bin/chmod")
MKDIR=("/bin/mkdir" "-p")

# Test if a location is writeable by trying to write to it. Windows does not let
# you test writeability other than by writing: https://stackoverflow.com/q/1999988
test_writeable() {
  path="${1:-}/test.txt"
  if touch "${path}" 2>/dev/null; then
    rm "${path}"
    return 0
  else
    return 1
  fi
}

get_last_github_author_email() {
  jq -r --arg default "$1" '.check_suite // .workflow_run // .sender // . | .head_commit // .commit.commit // . | .author.email // .pusher.email // .email // "$default"' "${GITHUB_EVENT_PATH}"
}
get_last_github_author_name() {
  jq -r '.pull_request // .check_suite // .workflow_run // .issue // .sender // .commit // .repository // . | .head_commit // .commit // . | .author.name // .pusher.name // .login // .user.login // .owner.login // ""' "${GITHUB_EVENT_PATH}"
}

configure_git() {
  # This installer is often run during github actions, so we need to make sure
  # that the git user is set.
  if command_exists git; then
    # If we get the name and it succeeds
    if git config --global user.name >/dev/null 2>&1; then
      # And that name is not empty
      if [[ -z "$(git config --global user.name)" ]]; then
        git config --global user.name "$(get_last_github_author_name)"
      fi
    else
      git config --global user.email "$(get_last_github_author_name)"
    fi
    local -r user="$(git config --global user.name)"
    if git config --global user.email >/dev/null 2>&1; then
      if [[ -z "$(git config --global user.email)" ]]; then
        git config --global user.email "$(get_last_github_author_email ${user})"
      fi
    else
      git config --global user.email "$(get_last_github_author_email ${user})"
    fi
  fi

}

download_shell_scripts() {
  local releases_url="https://api.github.com/repos/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/releases/latest"

  if command_exists git; then
    configure_git
    local need_to_clone=true
    if [[ -d ${DEFAULT_INSTALL_DIR} ]]; then
      if [[ $(git -C "${DEFAULT_INSTALL_DIR}" remote -v) =~ (${SHELL_SCRIPTS_GITHUB_REPOSITORY}) ]]; then
        need_to_clone=false
        notice "Updating shell-scripts..."
        git -C "${DEFAULT_INSTALL_DIR}" stash
        git -C "${DEFAULT_INSTALL_DIR}" reset --hard HEAD
        git -C "${DEFAULT_INSTALL_DIR}" pull -f
        git -C "${DEFAULT_INSTALL_DIR}" stash pop
      else
        mv "${DEFAULT_INSTALL_DIR}" "${DEFAULT_INSTALL_DIR}-old"
      fi
    fi

    if [[ ${need_to_clone} == true ]]; then
      git clone "https://github.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}.git" "${DEFAULT_INSTALL_DIR}"
    fi

  fi
}

download() {
  file="$1"
  url="$2"
  if command_exists curl; then
    curl --fail --silent --location --output $file $url
  elif command_exists wget; then
    wget --quiet --output-document=$file $url
  elif command_exists fetch; then
    fetch --quiet --output=$file $url
  else
    error "No HTTP download program (curl, wget, fetch) found, exiting…"
    return 1
  fi
}

unpack() {
  archive=$1
  bin_dir=$2
  sudo=${3-}

  case "$archive" in
  *.tar.gz)
    flags=$(test -n "${VERBOSE-}" && echo "-xzvof" || echo "-xzof")
    ${sudo} tar "${flags}" "${archive}" -C "${bin_dir}"
    return 0
    ;;
  *.zip)
    flags=$(test -z "${VERBOSE-}" && echo "-qqo" || echo "-o")
    UNZIP="${flags}" ${sudo} unzip "${archive}" -d "${bin_dir}"
    return 0
    ;;
  esac

  error "Unknown package extension."
  printf "\n"
  info "This almost certainly results from a bug in this script--please file a"
  info "bug report at https://github.com/starship/starship/issues"
  return 1
}

install() {
  ext="$1"

  if test_writeable "${BIN_DIR}"; then
    sudo=""
    msg="Installing Starship, please wait…"
  else
    warn "Escalated permissions are required to install to ${BIN_DIR}"
    elevate_priv
    sudo="sudo"
    msg="Installing Starship as root, please wait…"
  fi
  info "${msg}"

  archive=$(get_tmpfile "${ext}")

  # download to the temp file
  download "${archive}" "${URL}"

  # unpack the temp file to the bin dir, using sudo if required
  unpack "${archive}" "${BIN_DIR}" "${sudo}"
}

# Currently supporting:
#   - win (Git Bash)
#   - darwin
#   - linux
#   - linux_musl (Alpine)
#   - freebsd
detect_platform() {
  platform="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case "${platform}" in
  msys_nt*) platform="pc-windows-msvc" ;;
  cygwin_nt*) platform="pc-windows-msvc" ;;
  # mingw is Git-Bash
  mingw*) platform="pc-windows-msvc" ;;
  # use the statically compiled musl bins on linux to avoid linking issues.
  linux) platform="unknown-linux-musl" ;;
  darwin) platform="apple-darwin" ;;
  freebsd) platform="unknown-freebsd" ;;
  *)
    error "Unsupported platform: ${platform}"
    exit 1
    ;;
  esac

  printf '%s' "${platform}"
}

not_in_path() {
  tr ':' '\n' <<<"${PATH}" | grep -q -e "^$1$"
}
add_to_path() {
  if [[ -d "${1}" ]]; then
    if [[ -z "${PATH}" ]]; then
      export PATH="${1}"
    elif not_in_path "${1}"; then
      export PATH="${1}:${PATH}"
    fi
  fi
}

check_bin_dir() {
  bin_dir="${1%/}"

  if [[ ! -d "${BIN_DIR}" ]]; then
    error "Installation location ${BIN_DIR} does not appear to be a directory"
    info "Make sure the location exists and is a directory, then try again."
    exit 1
  fi

  # https://stackoverflow.com/a/11655875
  good=$(
    IFS=:
    for path in ${PATH}; do
      if [[ "${path%/}" = "${bin_dir}" ]]; then
        printf 1
        break
      fi
    done
  )

  if [[ "${good}" != "1" ]]; then
    warn "Bin directory ${bin_dir} is not in your \$PATH"
  fi
}

check_bin_dir "${BIN_DIR}"
install "${EXT}"
