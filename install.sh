#!/usr/bin/env bash
# shellcheck disable=SC2034

# Download the latest version of the script from the following URL:
# https://raw.githubusercontent.com/bitflight-devops/scripts/master/install.sh

set -eu
BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

# BFD == BitFlight Devops
SHELL_SCRIPTS_OWNER="bitflight-devops"
SHELL_SCRIPTS_REPOSITORY_NAME="shell-scripts"
SHELL_SCRIPTS_GITHUB_REPOSITORY="${SHELL_SCRIPTS_OWNER}/${SHELL_SCRIPTS_REPOSITORY_NAME}"

command_exists() { command -v "$@" >/dev/null 2>&1; }
is_scripts_lib_dir() { [[ -f "${1}/.scripts.lib.md" ]]; }

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

# Duplicate of function from lib/github_core_functions.sh
escape_github_command_data() {
  # Escape the GitHub string variable character to %25
  # Escape any carrage returns to %0D
  # Escape any remaining newlines to %0A
  local -r data="${1}"
  printf '%s' "${data}" | perl -ne '$_ =~ s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g;print;'
}

# Duplicate of function in lib/log_functions.sh
get_log_type() {
  set +x
  LOG_TYPES=(
    "error"
    "info"
    "warning"
    "notice"
    "debug"
  )
  local -r logtype="$(tr '[:upper:]' '[:lower:]' <<<"${1}")"
  if [[ "${LOG_TYPES[*]}" =~ ( |^)"${logtype}"( |\$) ]]; then
    printf '%s' "${logtype}"
  else
    echo ""
  fi
}
get_log_color() {
  if [[ -n ${GITHUB_ACTIONS-} ]]; then
    printf '%s' "::"
    return
  elif [[ -n ${CI-} ]]; then
    printf '%s' "##"
    return
  fi

  LOG_COLOR_error="${RED}"
  LOG_COLOR_info="${GREEN}"
  LOG_COLOR_warning="${YELLOW}"
  LOG_COLOR_notice="${MAGENTA}"
  LOG_COLOR_debug="${GREY}"

  local -r logtype="$(get_log_type "${1}")"
  if [[ -z "${logtype}" ]]; then
    printf '%s' "${NO_COLOR}"
  else
    eval 'printf "%s" "${LOG_COLOR_'"${logtype}"'}"'
  fi
}

simple_log() {
  local -r logtype="$(get_log_type "${1}")"
  local -r logcolor="$(get_log_color "${logtype}")"
  if [[ -z "${logtype}" ]]; then
    printf '%s%s\n' "${NO_COLOR}" "${*}"
  else
    shift
    if [[ "${logcolor}" != "::" ]]; then
      printf -v log_prefix '%s%s%-7s%s //%s' "${BOLD}" "${logcolor}" "${logtype}" "${logcolor}" "${NO_COLOR}"
      printf -v space '%*s' '10' ''
      local msg="$(awk -v space="${space}" '{if (NR!=1) x = space} {print x,$0}' RS='\n|(\\\\n)' <<<"${*}")"
    else
      printf -v log_prefix '::%s ::' "${logtype}"
      local -r msg="$(escape_github_command_data "${*}")"
    fi
    printf '%s%s\n' "${log_prefix}" "${msg}"
  fi
}

abort() {
  simple_log "error" "$@" >&2
  exit 1
}

error() { simple_log error "$@"; }
warn() { simple_log warning "$@"; }
notice() { simple_log notice "$@"; }
info() { simple_log info "$@"; }
debug() { simple_log debug "$@"; }
chomp() { printf "%s" "${1/"$'\n'"/}"; }

ohai() {
  printf "${BLUE}==>${BOLD} %s${NO_COLOR}\n" "$(shell_join "$@")"
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

if [[ -n ${GITHUB_ACTIONS-} ]]; then
  BFD_PREFIX="${HOME}"
  CI=true
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]; then
  abort "Cannot run force-interactive mode in CI."
fi
# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]; then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z "${NONINTERACTIVE-}" ]]; then
  if [[ -n "${CI-}" ]]; then
    warn 'Running in non-interactive mode because `$CI` is set.'
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]; then
    if [[ -z "${INTERACTIVE-}" ]]; then
      warn 'Running in non-interactive mode because `stdin` is not a TTY.'
      NONINTERACTIVE=1
    else
      warn 'Running in interactive mode despite `stdin` not being a TTY because `$INTERACTIVE` is set.'
    fi
  fi
else
  ohai 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
fi

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
    # On ARM macOS, this script installs to /opt/${SHELL_SCRIPTS_OWNER} only
    BFD_PREFIX_DEFAULT="/opt/${SHELL_SCRIPTS_OWNER}"
    BFD_REPOSITORY="${BFD_PREFIX:-${BFD_PREFIX_DEFAULT}}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
  else
    # On Intel macOS, this script installs to /usr/local only
    BFD_PREFIX_DEFAULT="/usr/local"
    BFD_REPOSITORY="${BFD_PREFIX:-${BFD_PREFIX_DEFAULT}}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
  fi
  BFD_CACHE="${HOME}/Library/Caches/${SHELL_SCRIPTS_OWNER}"

  STAT_PRINTF=("stat" "-f")
  PERMISSION_FORMAT="%A"
  BIN_FALSE=("/usr/bin/false")
  CHOWN=("/usr/sbin/chown")
  CHGRP=("/usr/bin/chgrp")
  GROUP="admin"
  TOUCH=("/usr/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "root" -g "wheel" -m "0755")
else
  UNAME_MACHINE="$(uname -m)"

  # On Linux, it installs to /home/${SHELL_SCRIPTS_GITHUB_REPOSITORY} if you have sudo access
  # and ~/.bitflight-devops (which is unsupported) if run interactively.
  BFD_PREFIX_DEFAULT="/home/${SHELL_SCRIPTS_OWNER}"
  BFD_REPOSITORY="${BFD_PREFIX:-${BFD_PREFIX_DEFAULT}}/.${SHELL_SCRIPTS_REPOSITORY_NAME}"
  BFD_CACHE="${HOME}/.cache/${SHELL_SCRIPTS_OWNER}"

  STAT_PRINTF=("stat" "--printf")
  PERMISSION_FORMAT="%a"
  BIN_FALSE=("/bin/false")
  CHOWN=("/bin/chown")
  CHGRP=("/bin/chgrp")
  GROUP="$(id -gn)"
  TOUCH=("/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "${USER}" -g "${GROUP}" -m "0755")
fi
CHMOD=("/bin/chmod")
MKDIR=("/bin/mkdir" "-p")

unset HAVE_SUDO_ACCESS # unset this from the environment

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]; then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]; then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]; then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    if [[ -n "${NONINTERACTIVE-}" ]]; then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -z "${HOMEBREW_ON_LINUX-}" ]] && [[ "${HAVE_SUDO_ACCESS}" -ne 0 ]]; then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

root_available() {
  local -r user="$(id -un 2>/dev/null || true)"
  if [[ ${user} != 'root' ]]; then
    if command_exists sudo; then
      if [[ $(SUDO_ASKPASS="${BIN_FALSE[*]}" sudo -A sh -c 'whoami;whoami' 2>&1 | wc -l) -eq 2 ]]; then
        echo "sudo"
        return 0
      elif groups "${user}" | grep -q '(^|\b)(sudo|wheel)(\b|$)' && [[ -n ${INTERACTIVE-} ]]; then
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
  if local SUDO="$(root_available)"; then
    ${SUDO} "${@}"
  else
    abort 'This command needs the ability to run other commands as root.\nWe are unable to find "sudo" available to make this happen.'
  fi
}

if [[ -n ${NONINTERACTIVE-} ]]; then
  BFD_PREFIX="${HOME}"
fi

# Test if a location is writeable by trying to write to it. Windows does not let
# you test writeability other than by writing: https://stackoverflow.com/q/1999988
test_writeable() {
  for path in "$@"; do
    if [[ -d "${path}" ]]; then
      "${TOUCH[@]:-touch}" "${path%/}"/test-writeable-file 2>/dev/null
      if [[ -f "${path%/}"/test-writeable-file ]]; then
        rm "${path%/}"/test-writeable-file
      else
        return 1
      fi
    fi
  done
  return 0
}

require_sudo() {

  local -r user="$(id -un 2>/dev/null || true)"
  local -r SUDO_CMD="$(root_available)"
  ROOT_IS_AVAILABLE=$?
  REQUIRE_SUDO=1
  if ! "${MKDIR[@]}" "${BFD_CACHE}" "${BFD_REPOSITORY}" 2>/dev/null; then
    if ! ${SUDO_CMD} "${MKDIR[@]}" "${BFD_CACHE}" "${BFD_REPOSITORY}" 2>/dev/null; then
      ohai "Unable to create ${BFD_CACHE} and ${BFD_REPOSITORY}."
      REQUIRE_SUDO=1
    else
      "${CHOWN[@]}" "${user}" "${BFD_CACHE}" 2>/dev/null || true
      "${CHOWN[@]}" "${user}" "${BFD_REPOSITORY}" 2>/dev/null || true
      ${SUDO_CMD} "${CHMOD[@]}" "ugo+wrx" "${BFD_CACHE}" 2>/dev/null
      ${SUDO_CMD} "${CHMOD[@]}" "ugo+wrx" "${BFD_REPOSITORY}" 2>/dev/null
      REQUIRE_SUDO=0
    fi
  else
    "${CHOWN[@]}" "${user}" "${BFD_CACHE}" 2>/dev/null || true
    "${CHOWN[@]}" "${user}" "${BFD_REPOSITORY}" 2>/dev/null || true
    "${CHMOD[@]}" "ugo+wrx" "${BFD_CACHE}" 2>/dev/null
    "${CHMOD[@]}" "go+rx" "${BFD_REPOSITORY}" 2>/dev/null
    REQUIRE_SUDO=0
  fi
  if ! test_writeable "${BFD_CACHE}" "${BFD_REPOSITORY}"; then
    ohai "Unable to write to ${BFD_CACHE} and ${BFD_REPOSITORY}."
    REQUIRE_SUDO=1
  fi

  if [[ ${REQUIRE_SUDO} -eq 1 ]] && [[ ${ROOT_IS_AVAILABLE} -eq 1 ]]; then
    ohai "This command requires root access to install the scripts to the ${BFD_REPOSITORY}.\nYou can set a different install prefix using the BFD_PREFIX environment variable."
  fi
  return "${REQUIRE_SUDO}"
}
if ! have_sudo_access && require_sudo; then
  ohai "This script requires sudo access to install to the selected directory."
  ohai "If you already have sudo access, you can run this script with 'sudo'."
  abort "Please re-run this script with sudo."
fi

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
        git config --global user.email "$(get_last_github_author_email "${user}")"
      fi
    else
      git config --global user.email "$(get_last_github_author_email "${user}")"
    fi
  fi

}

SHELL_SCRIPTS_REMOTE_GITHUB_REPOSITORY="https://github.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}.git"
SHELL_SCRIPTS_RELEASES_URL="https://api.github.com/repos/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/releases/latest"
download_shell_scripts() {
  cd "${BFD_REPOSITORY}" >/dev/null || return
  if command_exists git; then

    info "Initialising git directory" "${BFD_REPOSITORY}"
    # we do it in four steps to avoid merge errors when reinstalling
    execute "git" "init" "-q"
    info "Configuring git user details"
    configure_git
    # "git remote add" will fail if the remote is defined in the global config
    execute "git" "config" "remote.origin.url" "${SHELL_SCRIPTS_REMOTE_GITHUB_REPOSITORY}"
    execute "git" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"

    # ensure we don't munge line endings on checkout
    execute "git" "config" "core.autocrlf" "false"

    execute "git" "fetch" "--force" "origin"
    execute "git" "fetch" "--force" "--tags" "origin"

    execute "git" "reset" "--hard" "origin/main"
    info "Pulling latest shell scripts - starting..."
    execute "git" "-q" "pull"
    info "Pulling latest shell scripts - completed."
  else
    if download "${BFD_CACHE%/}/master.zip" "${releases_url}"; then
      unpack "${BFD_CACHE%/}/master.zip" "${BFD_REPOSITORY}"
    else
      abort "Unable to download shell-scripts from ${releases_url}."
    fi
  fi
}

download() {
  file="$1"
  url="$2"
  if command_exists curl; then
    curl --fail --silent --location --output "${file}" "${url}"
  elif command_exists wget; then
    wget --quiet --output-document="${file}" "${url}"
  elif command_exists fetch; then
    fetch --quiet --output="${file}" "${url}"
  else
    error "No HTTP download program (curl, wget, fetch) found, exiting…"
    return 1
  fi
}

unpack() {
  archive=$1
  bin_dir=$2
  sudo=${3-}

  case "${archive}" in
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
  *)
    error "Unknown package extension."
    printf "\n"
    info "This almost certainly results from a bug in this script--please file a"
    info "bug report at https://github.com/starship/starship/issues"
    return 1
    ;;
  esac
}

execute() {
  if ! "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}
getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

ring_bell() {
  # Use the shell's audible bell.
  if [[ -t 1 ]]; then
    printf "\a"
  fi
}

get_permission() {
  "${STAT_PRINTF[@]}" "${PERMISSION_FORMAT}" "$1"
}

user_only_chmod() {
  [[ -d "$1" ]] && [[ "$(get_permission "$1")" != 75[0145] ]]
}

exists_but_not_writable() {
  [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
}

get_owner() {
  "${STAT_PRINTF[@]}" "%u" "$1"
}

file_not_owned() {
  [[ "$(get_owner "$1")" != "$(id -u)" ]]
}

get_group() {
  "${STAT_PRINTF[@]}" "%g" "$1"
}

file_not_grpowned() {
  [[ " $(id -G "${USER}") " != *" $(get_group "$1") "* ]]
}
# Search for the given executable in PATH (avoids a dependency on the `which` command)
which() {
  # Alias to Bash built-in command `type -P`
  type -P "$@"
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

  if [[ ! -d "${bin_dir}" ]]; then
    error "Installation location ${bin_dir} does not appear to be a directory"
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
# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "/usr" || exit 1

install() {
  notice "Installing ${SHELL_SCRIPTS_GITHUB_REPOSITORY} to ${BFD_REPOSITORY}"
  configure_git
  info "Checking permissions"
  require_sudo
  info "Downloading and installing shell-scripts"
  download_shell_scripts
  notice "Installed"
  export BFD_REPOSITORY
  info "To use, run: source ${BFD_REPOSITORY}/lib/bootstrap.sh"
}

# check_bin_dir "${BIN_DIR}"
install
if [[ -z "${NONINTERACTIVE-}" ]]; then
  ring_bell
  # wait_for_user
fi

# Invalidate sudo timestamp before exiting (if it wasn't active before).
if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2>/dev/null; then
  trap '/usr/bin/sudo -k' EXIT
fi
