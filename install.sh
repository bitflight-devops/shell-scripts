#!/usr/bin/env bash
## <script src="https://get-fig-io.s3.us-west-1.amazonaws.com/readability.js"></script>
## <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/themes/prism-okaidia.min.css" rel="stylesheet" />
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-core.min.js" data-manual></script>
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-bash.min.js"></script>
## <style>body {color: #272822; background-color: #272822; font-size: 0.8em;} </style>

# shellcheck disable=SC2034

# ENVIRONMENT VARIABLES
# ----------------------------------------
# NONINTERACTIVE=1    # Set this to 1 to disable interactive prompts
# INTERACTIVE=1       # Set this to 1 to enable interactive prompts
# BFD_CLEAN_INSTALL=1 # Set to 1 to force a clean install

# Download the latest version of the script from the following URL:
# https://raw.githubusercontent.com/bitflight-devops/scripts/master/install.sh

set -eu
# BFD == BitFlight Devops
SHELL_SCRIPTS_OWNER="bitflight-devops"
SHELL_SCRIPTS_REPOSITORY_NAME="shell-scripts"
SHELL_SCRIPTS_GITHUB_REPOSITORY="${SHELL_SCRIPTS_OWNER}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
if [[ -n "${SUDO_USER:-}" ]]; then
  MAIN_USER="${SUDO_USER}"
else
  MAIN_USER="$(id -un 2> /dev/null || true)"
fi
command_exists() { command -v "$@" > /dev/null 2>&1; }
is_scripts_lib_dir() { [[ -f "${1}/.scripts.lib.md" ]]; }
downloader_installed() {
  command_exists curl || command_exists wget || command_exists fetch
}
# by using a HEREDOC, we are disabling shellcheck and shfmt
set +e
read -r -d '' LOOKUP_SHELL_FUNCTION << 'EOF'
	lookup_shell() {
		export whichshell
		case ${ZSH_VERSION:-} in *.*) { whichshell=zsh;return;};;esac
		case ${BASH_VERSION:-} in *.*) { whichshell=bash;return;};;esac
		case "${VERSION:-}" in *zsh*) { whichshell=zsh;return;};;esac
		case "${SH_VERSION:-}" in *PD*) { whichshell=sh;return;};;esac
		case "${KSH_VERSION:-}" in *PD*|*MIRBSD*) { whichshell=ksh;return;};;esac
	}
EOF
eval "${LOOKUP_SHELL_FUNCTION}"
# shellcheck enable=all
lookup_shell
set -e
is_zsh() {
  [[ "${whichshell:-}" == "zsh" ]]
}

sourced=0
if [[ -n ${ZSH_VERSION:-} ]]; then
  case ${ZSH_EVAL_CONTEXT:-} in *:file) sourced=1 ;; esac
elif [[ -n ${BASH_VERSION:-} ]]; then
  (return 0 2> /dev/null) && sourced=1
else # All other shells: examine $0 for known shell binary filenames.
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh | -sh | dash | -dash) sourced=1 ;; esac
fi

in_quiet_mode() {
  if [[ -n ${DEBUG:-} ]]; then
    # not quiet
    return 1
  elif [[ -n ${SHELL_SCRIPTS_QUIET:-} ]]; then
    # quiet
    return 0
  elif [[ ${sourced} -eq 1 ]] && [[ ! -t 0 ]]; then
    # sourced but not interactive - quiet
    return 0
  else
    # not sourced or interactive - not quiet
    return 1
  fi
}

run_quietly() {
  if in_quiet_mode; then
    "$@" > /dev/null 2>&1
  else
    "$@"
  fi
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

# Duplicate of function from lib/github_core_functions.sh
escape_github_command_data() {
  # Escape the GitHub string variable character to %25
  # Escape any carrage returns to %0D
  # Escape any remaining newlines to %0A
  local -r data="${1}"
  printf '%s' "${data}" | perl -ne '$_ =~ s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g;print;'
}
if ! downloader_installed; then
  abort "curl, wget, or fetch is required to download files."
fi
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

source <(download "-" "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/feat/eb_validation_test/simple_log.sh")

execute() {
  if ! run_quietly "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

ohai() {
  run_quietly printf "${BLUE}==>${BOLD} %s${COLOR_RESET}\n" "$(shell_join "$@")"
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
# if [ -z "${BASH_VERSION:-}" ]; then
#   abort "Bash is required to interpret this script."
# fi

if [[ -n ${GITHUB_ACTIONS:+x} ]]; then
  BFD_PREFIX="${HOME%./}"
fi
if [[ -n "${BFD_REPOSITORY:-}" ]]; then
  if [[ -n "${BFD_CLEAN_INSTALL:-}" ]]; then
    # Try to safely remove the existing installation
    if [[ "${BFD_REPOSITORY}" == *"/${SHELL_SCRIPTS_REPOSITORY_NAME}" ]]; then
      rm -rf "${BFD_REPOSITORY}"
    fi
    timeNowSecondsEpoch=$(date +%s)
    if grep -q "${BFD_REPOSITORY}" "${HOME}/.bashrc"; then
      sed -i."${timeNowSecondsEpoch}" "/${BFD_REPOSITORY}/d" "${HOME}/.bashrc"
    fi
    if grep -q "${BFD_REPOSITORY}" "${HOME}/.zshrc"; then
      sed -i."${timeNowSecondsEpoch}" "/${BFD_REPOSITORY}/d" "${HOME}/.zshrc"
    fi
    if grep -q "${BFD_REPOSITORY}" "${HOME}/.profile"; then
      sed -i."${timeNowSecondsEpoch}" "/${BFD_REPOSITORY}/d" "${HOME}/.profile"
    fi
    if grep -q "${BFD_REPOSITORY}" "${HOME}/.bash_profile"; then
      sed -i."${timeNowSecondsEpoch}" "/${BFD_REPOSITORY}/d" "${HOME}/.bash_profile"
    fi
    unset BFD_REPOSITORY
  else
    # We are already installed.
    # Just trigger an update
    BFD_EXISTING_INSTALLATION="${BFD_REPOSITORY}"
  fi
fi

# Check if script is run with force-interactive mode in CI
if [[ -n ${CI-} && -n ${INTERACTIVE-} ]]; then
  abort "Cannot run force-interactive mode in CI."
fi
# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n ${INTERACTIVE-} && -n ${NONINTERACTIVE-} ]]; then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

debug "checking which mode to use"
# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z ${NONINTERACTIVE-} ]]; then
  if [[ -n ${CI-} ]]; then
    debug 'Running in non-interactive mode because `$CI` is set.'
    NONINTERACTIVE=1
    unset INTERACTIVE
  elif [[ ! -t 0 ]] && [[ ${sourced} -eq 1 ]]; then
    if [[ -z ${INTERACTIVE-} ]]; then
      debug 'Running in non-interactive mode because `stdin` is not a TTY.'
      NONINTERACTIVE=1
      unset INTERACTIVE
    else
      debug 'Running in interactive mode despite `stdin` not being a TTY because `$INTERACTIVE` is set.'
    fi
  else
    debug 'Running in interactive mode.'
    INTERACTIVE=1
    unset NONINTERACTIVE || true
  fi
else
  debug 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
fi

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z ${USER:-} ]]; then
  debug "No USER variable, creating one"
  USER="$(chomp "$(id -un)")"
  export USER
fi

# First check OS.
OS="$(/usr/bin/uname 2> /dev/null || uname)"
if [[ ${OS} == "Linux" ]]; then
  SHELL_SCRIPTS_LINUX=1
elif [[ ${OS} != "Darwin" ]]; then
  abort "shell-scripts is only supported on macOS and Linux."
fi
if [[ -n "${BFD_EXISTING_INSTALLATION:-}" ]]; then
  BFD_REPOSITORY="${BFD_EXISTING_INSTALLATION}"
else
  BFD_PREFIX_DEFAULT="${HOME}/.local/${SHELL_SCRIPTS_OWNER}"
  BFD_REPOSITORY="${BFD_PREFIX:-${BFD_PREFIX_DEFAULT}}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
fi
if [[ -z ${SHELL_SCRIPTS_LINUX-} ]]; then
  UNAME_MACHINE="$(/usr/bin/uname -m)"

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
  local -r user="$(id -un 2> /dev/null || true)"
  if [[ ${user} == "root" ]]; then

    return 0
  fi
  if [[ ! -x "/usr/bin/sudo" ]]; then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n ${SUDO_ASKPASS-} ]]; then
    SUDO+=("-A")
  elif [[ -n ${NONINTERACTIVE-} ]]; then
    SUDO+=("-n")
  fi

  if [[ -z ${HAVE_SUDO_ACCESS-} ]]; then
    if [[ -n ${NONINTERACTIVE-} ]]; then
      "${SUDO[@]}" -l mkdir &> /dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &> /dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -z ${HOMEBREW_ON_LINUX-} ]] && [[ ${HAVE_SUDO_ACCESS} -ne 0 ]]; then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

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
    execute "${@}"
  elif [[ ${rv} -eq 0 ]] && [[ ${sd} == 'sudo' ]]; then
    execute sudo "${@}"
  else
    abort 'This command needs the ability to run other commands as root.\nWe are unable to find "sudo" available to make this happen.'
  fi
}

if [[ -n ${NONINTERACTIVE:-} ]]; then
  BFD_PREFIX="${HOME}"
fi

# Test if a location is writeable by trying to write to it. Windows does not let
# you test writeability other than by writing: https://stackoverflow.com/q/1999988
test_writeable() {
  local path
  for path in "$@"; do
    if [[ -d ${path} ]]; then
      "${TOUCH[@]:-touch}" "${path%/}"/test-writeable-file 2> /dev/null
      if [[ -f "${path%/}"/test-writeable-file ]]; then
        rm "${path%/}"/test-writeable-file
      else
        return 1
      fi
    fi
  done
  return 0
}

create_script_directory() {
  local -r user="$(id -un 2> /dev/null || true)"
  local -r path="$1"
  local -r permissions="0755"
  local fix_ownership='false'
  if [[ -d ${path} ]]; then
    if ! test_writeable "${path}"; then
      info "The directory ${COLOR_YELLOW}${path}${COLOR_RESET}\nis not writeable by the current user ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}.\nWe will attempt to change the permissions \nof the directory to ${permissions}."
    else
      info "The directory ${COLOR_YELLOW}${path}${COLOR_RESET}\nis available and writeable by the user ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}."
      return 0
    fi
  else

    info "Attempting to create ${COLOR_YELLOW}${path}${COLOR_RESET} as ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}."
    if ! execute "${MKDIR[@]}" "${path}"; then
      if [[ ${user} != 'root' ]]; then
        if ! run_as_root "${MKDIR[@]}" "${path}"; then
          abort "Failed to create ${COLOR_YELLOW}${path}${RED} as root."
        else
          fix_ownership='true'
          info "Created ${COLOR_YELLOW}${path}${COLOR_RESET} as ${COLOR_BRIGHT_CYAN}root${COLOR_RESET}."
        fi
      else
        abort "Failed to create ${COLOR_YELLOW}${path}${RED}."
      fi
    else
      info "Created ${COLOR_YELLOW}${path}${COLOR_RESET} as ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}."
    fi
  fi

  if [[ -d ${path} ]] && [[ ${fix_ownership} == 'true' ]]; then
    info "Setting ownership on ${COLOR_YELLOW}${path}${COLOR_RESET} to ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}"
    run_as_root "${CHOWN[@]}" "${user}" "${path}" 2> /dev/null || abort "Failed to set ownership on ${COLOR_YELLOW}${path}${COLOR_RESET} to ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}"
    info "Setting permissions on ${COLOR_YELLOW}${path}${COLOR_RESET} to ${permissions}"
    run_as_root "${CHMOD[@]}" "${permissions}" "${path}" 2> /dev/null || abort "Failed to set permissions on ${COLOR_YELLOW}${path}${COLOR_RESET} to ${permissions}"
  fi

  info "Verifying that ${COLOR_YELLOW}${path}${COLOR_RESET}\nis writeable by the user ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}."
  if ! test_writeable "${path}"; then
    abort "The directory ${COLOR_YELLOW}${path}${RED}\nis inaccessible to user ${COLOR_BRIGHT_CYAN}${user}${RED}."
  else
    info "The directory ${COLOR_YELLOW}${path}${COLOR_RESET}\nis writeable by the user ${COLOR_BRIGHT_CYAN}${user}${COLOR_RESET}."
  fi

}

create_directories() {
  create_script_directory "${BFD_REPOSITORY}"
}

# require_sudo() {

#   local -r user="$(id -un 2>/dev/null || true)"
#   info "Running install as ${user}"
#   local -r SUDO_CMD="$(root_available)"
#   ROOT_IS_AVAILABLE=$?
#   REQUIRE_SUDO=0

#   if ! test_writeable "${BFD_REPOSITORY}"; then
#     ohai "Unable to write to ${BFD_REPOSITORY}."
#     REQUIRE_SUDO=0
#   fi

#   if [[ ${REQUIRE_SUDO} -eq 0 ]] && [[ ${ROOT_IS_AVAILABLE} -eq 1 ]]; then
#     ohai "This command requires root access to install the scripts to the ${BFD_REPOSITORY}.\nYou can set a different install prefix using the BFD_PREFIX environment variable."
#   fi

#   return "${REQUIRE_SUDO}"
# }

get_last_github_author_email() {
  if command_exists jq && [[ -f ${GITHUB_EVENT_PATH:-} ]]; then
    execute jq -r --arg default "$1" '.check_suite // .workflow_run // .sender // . | .head_commit // .commit.commit // . | .author.email // .pusher.email // .email // "$default"' "${GITHUB_EVENT_PATH:-}"
  fi
}
get_last_github_author_name() {
  if command_exists jq && [[ -f ${GITHUB_EVENT_PATH:-} ]]; then
    execute jq -r '.pull_request // .check_suite // .workflow_run // .issue // .sender // .commit // .repository // . | .head_commit // .commit // . | .author.name // .pusher.name // .login // .user.login // .owner.login // ""' "${GITHUB_EVENT_PATH:-}"
  fi
}

configure_git() {
  # This installer is often run during github actions, so we need to make sure
  # that the git user is set.
  if command_exists git; then
    # If we get the name and it succeeds
    if git config --global user.name > /dev/null 2>&1; then
      # And that name is not empty
      if [[ -z "$(git config --global user.name)" ]]; then
        git config --global user.name "$(get_last_github_author_name)"
      fi
    else
      git config --global user.email "$(get_last_github_author_name)"
    fi
    local -r user="$(git config --global user.name)"
    if git config --global user.email > /dev/null 2>&1; then
      if [[ -z "$(git config --global user.email)" ]]; then
        git config --global user.email "$(get_last_github_author_email "${user}")"
      fi
    else
      git config --global user.email "$(get_last_github_author_email "${user}")"
    fi
  else
    abort "Git is not installed."
  fi

}
git_ref_type() {
  if [[ -z $1 ]]; then
    echo "no_ref_given"
  elif git rev-parse -q --verify "$1^{tag}" 2> /dev/null; then
    echo tag
  elif git show-ref -q --verify "refs/heads/$1" 2> /dev/null; then
    echo "branch"
  elif git show-ref -q --verify "refs/tags/$1" 2> /dev/null; then
    echo "tag"
  elif git show-ref -q --verify "refs/remote/$1" 2> /dev/null; then
    echo "remote"
  elif git rev-parse --verify "$1^{commit}" > /dev/null 2>&1; then
    echo "hash"
  else
    echo "unknown"
  fi
  return 0
}

SHELL_SCRIPTS_REMOTE_GITHUB_REPOSITORY="https://github.com/${SHELL_SCRIPTS_GITHUB_REPOSITORY}.git"
SHELL_SCRIPTS_RELEASES_URL="https://api.github.com/repos/${SHELL_SCRIPTS_GITHUB_REPOSITORY}/releases/latest"
download_shell_scripts() {
  if [[ -z ${SHELL_SCRIPTS_REF-} ]]; then
    SHELL_SCRIPTS_REF="main"
  fi
  if command_exists git; then
    (

      cd "${BFD_REPOSITORY}" > /dev/null || abort "Failed to change to ${BFD_REPOSITORY}."
      info "Initialising git directory" "${COLOR_BG_BLACK}${COLOR_BRIGHT_YELLOW}${BFD_REPOSITORY}${COLOR_RESET}"
      # we do it in four steps to avoid merge errors when reinstalling
      execute "git" "init" "-q"
      # "git remote add" will fail if the remote is defined in the global config
      execute "git" "config" "remote.origin.url" "${SHELL_SCRIPTS_REMOTE_GITHUB_REPOSITORY}"
      execute "git" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"

      # ensure we don't munge line endings on checkout
      execute "git" "config" "core.autocrlf" "false"

      execute "git" "fetch" "--force" "origin" > /dev/null 2>&1
      execute "git" "fetch" "--force" "--tags" "origin" > /dev/null 2>&1
      execute "git" "remote" "set-head" "origin" "--auto" > /dev/null
      execute "git" "reset" "--hard" "origin/${SHELL_SCRIPTS_REF}" > /dev/null 2>&1
      info "Pulling latest shell scripts - starting..."
      execute "git" "pull" "--quiet" "--force" "origin" "${SHELL_SCRIPTS_REF}" > /dev/null 2>&1
      info "Pulling latest shell scripts - completed."
    )
  else
    (
      cd "${BFD_REPOSITORY}" > /dev/null || abort "Failed to change to ${BFD_REPOSITORY}."
      local bfd_cache="$(mktemp -d)"
      if download "${bfd_cache}/master.zip" "${SHELL_SCRIPTS_RELEASES_URL}"; then
        unpack "${bfd_cache}/master.zip" "${BFD_REPOSITORY}" && rm -rf "${bfd_cache}"
      else
        rm -rf "${bfd_cache}"
        abort_msg=(
          "Unable to download shell-scripts from\n"
          "\t${COLOR_BG_BLACK}${COLOR_BRIGHT_YELLOW}${SHELL_SCRIPTS_RELEASES_URL}${COLOR_RESET}"
        )
        abort "${abort_msg[*]}"
      fi
    )
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
  [[ -d $1 ]] && [[ "$(get_permission "$1")" != 75[0145] ]]
}

exists_but_not_writable() {
  [[ -e $1 ]] && ! [[ -r $1 && -w $1 && -x $1 ]]
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
  local -r item="$(trim "${1}")"
  local p="${PATH%:}"
  grep -q -v ":${item}:" <<< ":${p#:}:"
}
add_to_path() {
  # if [[ -d "${1}" ]]; then
  if [[ -z ${PATH} ]]; then
    export PATH="${1}"
    running_in_github_actions && echo "${1}" >> "${GITHUB_PATH}"
    debug "Path created: ${1}"
  elif not_in_path "${1}"; then
    export PATH="${1}:${PATH}"
    running_in_github_actions && echo "${1}" >> "${GITHUB_PATH}"
    debug "Path added: ${1}"
  fi
  # fi
}

check_bin_dir() {
  bin_dir="${1%/}"

  if [[ ! -d ${bin_dir} ]]; then
    error "Installation location ${bin_dir} does not appear to be a directory"
    info "Make sure the location exists and is a directory, then try again."
    exit 1
  fi

  # https://stackoverflow.com/a/11655875
  good=$(
    IFS=:
    for path in ${PATH}; do
      if [[ ${path%/} == "${bin_dir}" ]]; then
        printf 1
        break
      fi
    done
  )

  if [[ ${good} != "1" ]]; then
    warn "Bin directory ${bin_dir} is not in your \$PATH"
  fi
}

progress_bar() {
  NONINTERACTIVE=1 brew install curl | grep -oh '^' | while read -r line; do
    print "#"
  done
}

DEPENDENCIES=(
  git
  jq
  perl
)

if ! command_exists wget && ! command_exists curl; then
  DEPENDENCIES+=(
    curl
  )
fi

missing_dependencies() {
  REQUIRED_DEPENDENCIES=()
  for dependency in "${DEPENDENCIES[@]}"; do
    if ! command_exists "${dependency}"; then
      REQUIRED_DEPENDENCIES+=("${dependency}")
    fi
  done
  if [[ ${#REQUIRED_DEPENDENCIES[@]} -eq 0 ]]; then
    return 0
  fi
  printf '%s ' "${REQUIRED_DEPENDENCIES[@]}"
  return 1
}
# Repeat given char N times using shell function
repeat() {
  local start=1
  local end=${1:-80}
  local str="${2:-=}"
  local range=$(seq "${start}" "${end}")
  for i in ${range}; do echo -n "${str}"; done
}

install_dependencies() {
  local dependencies=("$@")
  if [[ -n ${SHELL_SCRIPTS_LINUX:-} ]]; then
    if ! have_sudo_access || [[ $(id -un 2> /dev/null || echo "${USER:-}") != 'root'  ]]; then
      ohai "This script requires sudo access to install system dependencies."
      ohai "If you already have sudo access, you can run this script with 'sudo'."
      abort "Please re-run this script with sudo."
    fi
    if [[ -x "$(command -v apt-get)" ]]; then
      export DEBIAN_FRONTEND=noninteractive
      export APT_LISTCHANGES_FRONTEND=none
      # >/dev/null 2>&1
      run_as_root apt-get -o Acquire::Max-FutureTime=86400 -qq -y update # Handle out of sync docker containers
      run_as_root apt-get -o Acquire::Max-FutureTime=86400 -o Dpkg::Options::="--force-confnew" install -qq -y "${dependencies[@]}" > /dev/null 2>&1
    elif [[ -x "$(command -v yum)" ]]; then
      run_as_root yum install -y "${dependencies[@]}"
    elif [[ -x "$(command -v pacman)" ]]; then
      run_as_root pacman --noconfirm -S "${dependencies[@]}"
    elif [[ -x "$(command -v apk)" ]]; then
      run_as_root apk update
      run_as_root apk add --no-cache "${dependencies[@]}"
    else
      NO_PACKAGE_MANAGER=true
    fi
  else
    if [[ -x "$(command -v brew)" ]]; then
      brew install "${dependencies[@]}"
    else
      NO_PACKAGE_MANAGER=true
    fi
  fi
  if [[ -n ${NO_PACKAGE_MANAGER:-} ]]; then
    abort "No package manager found. Please install ${COLOR_YELLOW}${dependencies[*]}${COLOR_RESET} manually."
  fi
  success "Installed ${COLOR_YELLOW}${dependencies[*]}${COLOR_RESET}."
}

installer_dependencies() {
  read -r -a REQUIRED_DEPENDENCIES <<< "$(missing_dependencies)" 2> /dev/null || read -r -A REQUIRED_DEPENDENCIES <<< "$(missing_dependencies)"

  INSTALL_DEPS=false
  if [[ ${#REQUIRED_DEPENDENCIES[@]} -eq 0 ]]; then
    INSTALL_DEPS=false
  elif [[ -n ${NONINTERACTIVE-} ]]; then
    INSTALL_DEPS=true
  elif [[ -n ${INTERACTIVE-} ]]; then
    # If we're running in an interactive shell, we need to ask the user for
    # permission to install the dependencies.

    local message="This script requires the following dependencies:\n"
    for i in "${REQUIRED_DEPENDENCIES[@]}"; do message="${message}  - ${COLOR_BRIGHT_CYAN}${i}${COLOR_RESET}\n"; done
    if root_available; then
      notice "${message}\nThese dependencies can be installed for you as root.\n"
      step "Do you want to install them now? [Y/n] "
      if is_zsh; then
        read -k 1 -r -q answer
      else
        read -r -n 1 -t 120 install_deps_answer
      fi
      printf "\n"
      if [[ ${install_deps_answer:-y} =~ [Yy] ]]; then
        INSTALL_DEPS=true
      fi
    else
      notice "${message}"
    fi
  fi

  if [[ ${INSTALL_DEPS:-} == 'true' ]]; then
    info "Installing dependencies…${COLOR_BRIGHT_CYAN}" "${REQUIRED_DEPENDENCIES[@]}" "${COLOR_RESET}"
    install_dependencies "${REQUIRED_DEPENDENCIES[@]}"
  elif [[ ${#REQUIRED_DEPENDENCIES[@]} -gt 0 ]]; then
    ohai "Skipping dependency installation…"
    abort "Please install ${COLOR_YELLOW}${REQUIRED_DEPENDENCIES[*]}${COLOR_RESET} manually."
  fi

}

print_or_execute() {
  if [[ ${1} == "print" ]]; then
    shift
    printf "    "
    printf "%s" "${@}"
  else
    shift
    execute "${@}"
  fi
}
shell_rc_file() {
  case "${SHELL}" in
    */bash*)
      shell_rc="${HOME}/.bashrc"
      ;;
    */zsh*)
      shell_rc="${HOME}/.zshrc"
      ;;
    *)
      shell_rc="${HOME}/.profile"
      export ENV=~/.profile
      ;;
  esac
  echo "${shell_rc}"
}

set_env_var() {
  local name="${1//\s/}"
  local value="$2"
  local file
  local prefix=''
  local use_root=false
  if [[ -n ${GITHUB_ACTIONS:+x} ]]; then
    file="${GITHUB_ENV}"
  else
    file="$(shell_rc_file)"
    prefix='export '
  fi
  if [[ -z ${file:-} ]]; then
    error "Could not find a shell profile file to set the environment variable in."
    return 1
  fi
  if [[ ! -f ${file} ]]; then
    "${TOUCH[@]:-touch}" "${file}" || return 1
  fi
  #  /[.*+?^${}()|[\]\\]/g, '\\$&'

  if [[ -n ${value} ]]; then
    if grep -q "^${prefix}${name}=" "${file}"; then
      perl -pi -e "s#^${prefix}${name}=.*#${prefix}${name}=${value}#g" "${file}" && return 0
    else
      echo "${prefix}${name}=${value}" >> "${file}" && return 0
    fi
  else
    perl -pi -e "/^${name}=.*/d" "${file}" && return 0
  fi
  return 1
}

next_steps() {

  result "Next steps:"
  RC_CONTENT="source \"${BFD_REPOSITORY}/.shellscriptsrc\""

  local shell_profile="$(shell_rc_file)"

  if [[ -n ${INTERACTIVE:-} ]]; then
    notice_msg=(
      "To use the installed functions add this to your scripts:\n"
      "${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${RC_CONTENT}${COLOR_RESET}"
    )
    step "${notice_msg[*]}"
    if [[ -f ${shell_profile} ]] && grep -m 1 -q -E '(BFD_REPOSITORY|shellscripts)' "${shell_profile}"; then
      matches="$(awk '/.*(BFD_REPOSITORY|shellscripts).*/ {print "On line "NR" --> "$0};' "${shell_profile}")"
      info_msg=(
        "Environment variable\n"
        "${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${RC_CONTENT}${COLOR_RESET}\n"
        "is possibly already set in ${shell_profile}.\n"
        "Matches:\n"
        "${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${matches}${COLOR_RESET}"
      )
      step "${debug_msg[*]}"
    else
      step_question_msg=(
        "Do you want to add this to\n"
        "\t${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${shell_profile}${COLOR_RESET}${COLOR_BRIGHT_WHITE} now? [Y/n] "
        "${COLOR_RESET}"
      )
      step_question "${step_question_msg[*]}"
      add_to_shell="$(bash -c 'read -r -n 1 -t 30 prompt; echo "${prompt:-}"')"
      printf "\n"
      if [[ ${add_to_shell:-y} =~ [Yy] ]]; then
        info_msg=("Adding script source:\n"
          "${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}"
          "${RC_CONTENT}"
          "${COLOR_RESET}\n"
          "to ${shell_profile}"
        )
        info "${info_msg[*]}"
        tee -a "${shell_profile}" <<< "${RC_CONTENT}" && return 0
      fi
    fi
    info_msg=(
      "Run this command in the shell to load the scripts now:\n"
      "\t${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${RC_CONTENT}${COLOR_RESET}\n"
      "Or reload the shell:\n"
      "\t${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}"
      "exec ${whichshell}${COLOR_RESET}"
    )
    info "${info_msg[*]}"
  fi

  if [[ -n ${NONINTERACTIVE:-} ]]; then

      info_msg=(
        "Adding environment variable\n"
        "\t${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${RC_CONTENT}${COLOR_RESET}"
    )
      info "${info_msg[*]}"
      if grep -m 1 -q -v -E '(BFD_REPOSITORY|shellscripts)' "${shell_profile}"; then
        tee -a "${shell_profile}" <<< "${RC_CONTENT}"
    fi
    if [[ -n ${GITHUB_ACTIONS:-} ]]; then
      set_env_var BFD_REPOSITORY "${BFD_REPOSITORY}" && return 0
    fi
  fi
}

installer_dependencies
if ! command_exists git && ! downloader_installed; then
  abort "Git, curl, wget, or fetch is required to download the scripts."
fi

install() {
  starting "Installing ${SHELL_SCRIPTS_GITHUB_REPOSITORY}"
  step "Validating git user name and email..."
  { execute configure_git && step_passed "Validated git user name and email"; } || step_failed "Failed to configure git"
  step "Creating install directory..."
  { execute create_directories && step_passed "Created install directory"; } || step_failed "Failed to create directories"
  step "Installing shell-scripts..."
  { execute download_shell_scripts && step_passed "Installed shell-scripts"; } || step_failed "Failed to install shell-scripts"
  next_steps

  finished "${START_ICON} Install completed"
  unset INTERACTIVE
  unset NONINTERACTIVE
  set +eu
}

# check_bin_dir "${BIN_DIR}"
install || failure "Installation failed"

if [[ -z ${NONINTERACTIVE-} ]]; then
  ring_bell
  # wait_for_user
fi

# Invalidate sudo timestamp before exiting (if it wasn't active before).
if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2> /dev/null; then
  trap '/usr/bin/sudo -k' EXIT
fi

# ------------------------------------------
#   Notes
# ------------------------------------------
#
# This script contains hidden JavaScript which is used to improve
# readability in the browser (via syntax highlighting, etc), right-click
# and "View source" of this page to see the entire bash script!
# -- style code from https://fig.io/install
