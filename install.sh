#!/usr/bin/env bash
## <script src="https://get-fig-io.s3.us-west-1.amazonaws.com/readability.js"></script>
## <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/themes/prism-okaidia.min.css" rel="stylesheet" />
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-core.min.js" data-manual></script>
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-bash.min.js"></script>
## <style>body {color: #272822; background-color: #272822; font-size: 0.8em;} </style>

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

COLOR_BOLD_BLACK=$'\e[1;30m'
COLOR_BOLD_RED=$'\e[1;31m'
COLOR_BOLD_GREEN=$'\e[1;32m'
COLOR_BOLD_YELLOW=$'\e[1;33m'
COLOR_BOLD_BLUE=$'\e[1;34m'
COLOR_BOLD_MAGENTA=$'\e[1;35m'
COLOR_BOLD_CYAN=$'\e[1;36m'
COLOR_BOLD_WHITE=$'\e[1;37m'
COLOR_BOLD=$'\e[1m'
COLOR_BOLD_YELLOW=$'\e[1;33m'
COLOR_RESET=$'\e[0m'
CLEAR_SCREEN="$(tput rc 2>/dev/null || printf '')"

COLOR_BRIGHT_BLACK=$'\e[0;90m'
COLOR_BRIGHT_RED=$'\e[0;91m'
COLOR_BRIGHT_GREEN=$'\e[0;92m'
COLOR_BRIGHT_YELLOW=$'\e[0;93m'
COLOR_BRIGHT_BLUE=$'\e[0;94m'
COLOR_BRIGHT_MAGENTA=$'\e[0;95m'
COLOR_BRIGHT_CYAN=$'\e[0;96m'
COLOR_BRIGHT_WHITE=$'\e[0;97m'

COLOR_BG_BLACK=$'\e[1;40m'
COLOR_BG_RED=$'\e[1;41m'
COLOR_BG_GREEN=$'\e[1;42m'
COLOR_BG_YELLOW=$'\e[1;43m'
COLOR_BG_BLUE=$'\e[1;44m'
COLOR_BG_MAGENTA=$'\e[1;45m'
COLOR_BG_CYAN=$'\e[1;46m'
COLOR_BG_WHITE=$'\e[1;47m'
COLOR_RESET=$'\e[0m'

INFO_ICON=$'ℹ️'
DEBUG_ICON=$'🛠️'
STARTING_STAR=$'⭐'
STEP_STAR=$'✨'
HOURGLASS_IN_PROGRESS=$'⏳' # ⏳ hourglass not done
HOURGLASS_DONE=$'⌛'        # ⌛ hourglass done
CHECK_MARK_BUTTON=$'✅'     # ✅ check mark button
CROSS_MARK=$'❌'            # ❌ cross mark

# BFD == BitFlight Devops
SHELL_SCRIPTS_OWNER="bitflight-devops"
SHELL_SCRIPTS_REPOSITORY_NAME="shell-scripts"
SHELL_SCRIPTS_GITHUB_REPOSITORY="${SHELL_SCRIPTS_OWNER}/${SHELL_SCRIPTS_REPOSITORY_NAME}"
MAIN_USER="$(id -un 2>/dev/null || true)"

sourced=0
if [[ -n ${ZSH_VERSION:-} ]]; then
  case ${ZSH_EVAL_CONTEXT:-} in *:file) sourced=1 ;; esac
elif [[ -n ${BASH_VERSION:-} ]]; then
  (return 0 2>/dev/null) && sourced=1
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
    "$@" >/dev/null 2>&1
  else
    "$@"
  fi
}

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
  if [[ -z ${GITHUB_ACTIONS:-} ]]; then
    LOG_TYPES+=(
      "success"
      "failure"
      "step"
    )
  fi
  local -r logtype="$(tr '[:upper:]' '[:lower:]' <<<"${1}")"
  if [[ ${LOG_TYPES[*]} =~ ( |^)"${logtype}"( |$) ]]; then
    printf '%s' "${logtype}"
  else
    echo ""
  fi
}

function failure() {
  local -r message="${*}"
  simple_log failure "${COLOR_BRIGHT_RED}${message}${COLOR_RESET}"
}

function success() {
  local -r message="${*}"
  simple_log success "${COLOR_BRIGHT_YELLOW}${message}${COLOR_RESET}" 2>&1
}

function start_step() {
  local -r message="${*}"
  simple_log step "${COLOR_BRIGHT_WHITE}${message}${COLOR_RESET}" 2>&1
}

get_log_color() {
  if [[ -n ${GITHUB_ACTIONS:-} ]]; then
    printf '%s' "::"
    return
  elif [[ -n ${CI:-} ]]; then
    printf '%s' "##"
    return
  fi

  LOG_COLOR_error="${RED}"
  LOG_COLOR_info="${GREEN}"
  LOG_COLOR_warning="${YELLOW}"
  LOG_COLOR_notice="${MAGENTA}"
  LOG_COLOR_debug="${GREY}"
  LOG_COLOR_step="${COLOR_BOLD_CYAN}"
  LOG_COLOR_failure="${COLOR_BG_YELLOW}${RED}"
  LOG_COLOR_success="${COLOR_BOLD_YELLOW}"
  local arg="$(tr '[:upper:]' '[:lower:]' <<<"${1}")"

  if [[ ! ${arg} =~ (success|failure|step) ]]; then
    local -r logtype="$(get_log_type "${arg}")"
  else
    local -r logtype="${arg}"
  fi
  if [[ -z ${logtype} ]]; then
    printf '%s' "${NO_COLOR}"
  else
    eval 'printf "%s" "${LOG_COLOR_'"${logtype}"'}"'
  fi
}

stripcolor() {
  # shellcheck disable=SC2001
  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" <<<"${*}"
}

indent_style() {
  local logtype="${1}"
  local -r width="${2}"

  local final_style=''
  case "${logtype}" in
  notice)
    style=" "
    final_style="${STARTING_STAR}"
    ;;
  step)
    style=" "
    final_style="${STEP_STAR}"
    ;;
  failure)
    style=" "
    final_style="${CROSS_MARK}"
    ;;
  success)
    style=" "
    final_style="${CHECK_MARK_BUTTON}"
    ;;
  info)
    style=" "
    final_style="${INFO_ICON} "
    # logtype=''
    ;;
  debug)
    style=" "
    final_style="${DEBUG_ICON:-} "
    ;;
  *)
    style=""
    final_style="-->"
    ;;
  esac
  local -r indent_length="$((width - ${#logtype}))"
  printf '%s' "$(tr '[:lower:]' '[:upper:]' <<<"${logtype}")"
  printf -- "${style}%.0s" $(seq "${indent_length}")
  printf '%s' "${final_style}"
}

simple_log() {
  in_quiet_mode && return 0
  local -r logtype="$(get_log_type "${1}")"
  local -r logcolor="$(get_log_color "${logtype}")"
  if [[ -z ${logtype} ]]; then
    printf '%s%s\n' "${NO_COLOR}" "${*}"
  else
    shift
    if [[ ${logcolor} != "::" ]]; then
      local indent_width=11
      local indent="$(indent_style "${logtype}" "${indent_width}")"
      printf -v log_prefix '%s%s%s%s%s' "${BOLD}" "${logcolor}" "${indent}" "${logcolor}" "${NO_COLOR}"
      # log_prefix_length="$(stripcolor "${log_prefix}" | wc -c)"
      printf -v space "%*s" "$((indent_width + 2))" ''
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

execute() {
  if ! run_quietly "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

error() { simple_log error "$@"; }
warn() { simple_log warning "$@"; }
warning() { simple_log warning "$@"; }
notice() { simple_log notice "$@"; }
info() { simple_log info "$@"; }
chomp() { printf "%s" "${1/"$'\n'"/}"; }
debug() {
  if [[ -n ${DEBUG:-} ]]; then
    simple_log debug "$@"
  fi
}
ohai() {
  run_quietly printf "${BLUE}==>${BOLD} %s${NO_COLOR}\n" "$(shell_join "$@")"
}

downloader_installed() {
  command_exists curl || command_exists wget || command_exists fetch
}
# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

if [[ -n ${GITHUB_ACTIONS:+x} ]]; then
  BFD_PREFIX="${HOME%./}"
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
OS="$(/usr/bin/uname 2>/dev/null || uname)"
if [[ ${OS} == "Linux" ]]; then
  SHELL_SCRIPTS_LINUX=1
elif [[ ${OS} != "Darwin" ]]; then
  abort "shell-scripts is only supported on macOS and Linux."
fi
BFD_PREFIX_DEFAULT="${HOME}"
BFD_REPOSITORY="${BFD_PREFIX:-${BFD_PREFIX_DEFAULT}}/.${SHELL_SCRIPTS_REPOSITORY_NAME}"

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
  local -r user="$(id -un 2>/dev/null || true)"
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
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -z ${HOMEBREW_ON_LINUX-} ]] && [[ ${HAVE_SUDO_ACCESS} -ne 0 ]]; then
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

create_script_directory() {
  local -r user="$(id -un 2>/dev/null || true)"
  local -r path="$1"
  local -r permissions="0755"
  local fix_ownership='false'
  if [[ -d ${path} ]]; then
    if ! test_writeable "${path}"; then
      info "The directory ${YELLOW}${path}${NO_COLOR}\nis not writeable by the current user ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}.\nWe will attempt to change the permissions \nof the directory to ${permissions}."
    else
      info "The directory ${YELLOW}${path}${NO_COLOR}\nis available and writeable by the user ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}."
      return 0
    fi
  else

    info "Attempting to create ${YELLOW}${path}${NO_COLOR} as ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}."
    if ! execute "${MKDIR[@]}" "${path}"; then
      if [[ ${user} != 'root' ]]; then
        if ! run_as_root "${MKDIR[@]}" "${path}"; then
          abort "Failed to create ${YELLOW}${path}${RED} as root."
        else
          fix_ownership='true'
          info "Created ${YELLOW}${path}${NO_COLOR} as ${COLOR_BRIGHT_CYAN}root${NO_COLOR}."
        fi
      else
        abort "Failed to create ${YELLOW}${path}${RED}."
      fi
    else
      info "Created ${YELLOW}${path}${NO_COLOR} as ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}."
    fi
  fi

  if [[ -d ${path} ]] && [[ ${fix_ownership} == 'true' ]]; then
    info "Setting ownership on ${YELLOW}${path}${NO_COLOR} to ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}"
    run_as_root "${CHOWN[@]}" "${user}" "${path}" 2>/dev/null || abort "Failed to set ownership on ${YELLOW}${path}${NO_COLOR} to ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}"
    info "Setting permissions on ${YELLOW}${path}${NO_COLOR} to ${permissions}"
    run_as_root "${CHMOD[@]}" "${permissions}" "${path}" 2>/dev/null || abort "Failed to set permissions on ${YELLOW}${path}${NO_COLOR} to ${permissions}"
  fi

  info "Verifying that ${YELLOW}${path}${NO_COLOR}\nis writeable by the user ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}."
  if ! test_writeable "${path}"; then
    abort "The directory ${YELLOW}${path}${RED}\nis inaccessible to user ${COLOR_BRIGHT_CYAN}${user}${RED}."
  else
    info "The directory ${YELLOW}${path}${NO_COLOR}\nis writeable by the user ${COLOR_BRIGHT_CYAN}${user}${NO_COLOR}."
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
  else
    abort "Git is not installed."
  fi

}
git_ref_type() {
  if [[ -z $1 ]]; then
    echo "no_ref_given"
  elif git rev-parse -q --verify "$1^{tag}" 2>/dev/null; then
    echo tag
  elif git show-ref -q --verify "refs/heads/$1" 2>/dev/null; then
    echo "branch"
  elif git show-ref -q --verify "refs/tags/$1" 2>/dev/null; then
    echo "tag"
  elif git show-ref -q --verify "refs/remote/$1" 2>/dev/null; then
    echo "remote"
  elif git rev-parse --verify "$1^{commit}" >/dev/null 2>&1; then
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

      cd "${BFD_REPOSITORY}" >/dev/null || abort "Failed to change to ${BFD_REPOSITORY}."
      info "Initialising git directory" "${COLOR_BG_BLACK}${COLOR_BRIGHT_YELLOW}${BFD_REPOSITORY}${COLOR_RESET}"
      # we do it in four steps to avoid merge errors when reinstalling
      execute "git" "init" "-q"
      # "git remote add" will fail if the remote is defined in the global config
      execute "git" "config" "remote.origin.url" "${SHELL_SCRIPTS_REMOTE_GITHUB_REPOSITORY}"
      execute "git" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"

      # ensure we don't munge line endings on checkout
      execute "git" "config" "core.autocrlf" "false"

      execute "git" "fetch" "--force" "origin" >/dev/null 2>&1
      execute "git" "fetch" "--force" "--tags" "origin" >/dev/null 2>&1
      execute "git" "remote" "set-head" "origin" "--auto" >/dev/null
      execute "git" "reset" "--hard" "origin/${SHELL_SCRIPTS_REF}" >/dev/null 2>&1
      info "Pulling latest shell scripts - starting..."
      execute "git" "pull" "--quiet" "--force" "origin" "${SHELL_SCRIPTS_REF}" >/dev/null 2>&1
      info "Pulling latest shell scripts - completed."
    )
  else
    (
      cd "${BFD_REPOSITORY}" >/dev/null || abort "Failed to change to ${BFD_REPOSITORY}."
      local bfd_cache="$(mktemp -d)"
      if download "${bfd_cache}/master.zip" "${SHELL_SCRIPTS_RELEASES_URL}"; then
        unpack "${bfd_cache}/master.zip" "${BFD_REPOSITORY}" && rm -rf "${bfd_cache}"
      else
        rm -rf "${bfd_cache}"
        abort "Unable to download shell-scripts from\n   ${COLOR_BG_BLACK}${COLOR_BRIGHT_YELLOW}${SHELL_SCRIPTS_RELEASES_URL}${NO_COLOR}"
      fi
    )
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
  grep -q -v ":${item}:" <<<":${p#:}:"
}
add_to_path() {
  # if [[ -d "${1}" ]]; then
  if [[ -z ${PATH} ]]; then
    export PATH="${1}"
    running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
    debug "Path created: ${1}"
  elif not_in_path "${1}"; then
    export PATH="${1}:${PATH}"
    running_in_github_actions && echo "${1}" >>"${GITHUB_PATH}"
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

export DEPENDENCIES=(
  git
  jq
  wget
  perl
)

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
    if ! have_sudo_access || [[ ${MAIN_USER} != 'root' ]]; then
      ohai "This script requires sudo access to install system dependencies."
      ohai "If you already have sudo access, you can run this script with 'sudo'."
      abort "Please re-run this script with sudo."
    fi
    if [[ -x "$(command -v apt-get)" ]]; then
      export DEBIAN_FRONTEND=noninteractive
      export APT_LISTCHANGES_FRONTEND=none
      # >/dev/null 2>&1
      run_as_root apt-get -o Acquire::Max-FutureTime=86400 -qq -y update # Handle out of sync docker containers
      run_as_root apt-get -o Acquire::Max-FutureTime=86400 -o Dpkg::Options::="--force-confnew" install -qq -y "${dependencies[@]}" >/dev/null 2>&1
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
    abort "No package manager found. Please install ${YELLOW}${dependencies[*]}${NO_COLOR} manually."
  fi
  success "Installed ${YELLOW}${dependencies[*]}${NO_COLOR}."
}

installer_dependencies() {
  read -r -a REQUIRED_DEPENDENCIES <<<"$(missing_dependencies)" 2>/dev/null || read -r -A REQUIRED_DEPENDENCIES <<<"$(missing_dependencies)"

  INSTALL_DEPS=false
  if [[ ${#REQUIRED_DEPENDENCIES[@]} -eq 0 ]]; then
    INSTALL_DEPS=false
  elif [[ -n ${NONINTERACTIVE-} ]]; then
    INSTALL_DEPS=true
  elif [[ -n ${INTERACTIVE-} ]]; then
    # If we're running in an interactive shell, we need to ask the user for
    # permission to install the dependencies.

    local message="This script requires the following dependencies:\n"
    for i in "${REQUIRED_DEPENDENCIES[@]}"; do message="${message}  - ${COLOR_BRIGHT_CYAN}${i}${NO_COLOR}\n"; done
    if root_available; then
      notice "${message}\nThese dependencies can be installed for you as root.\n"
      start_step "Do you want to install them now? [Y/n] "
      read -r -n 1 -t 120 install_deps_answer
      printf "\n"
      if [[ ${install_deps_answer:-y} =~ [Yy] ]]; then
        INSTALL_DEPS=true
      fi
    else
      notice "${message}"
    fi
  fi

  if [[ ${INSTALL_DEPS:-} == 'true' ]]; then
    info "Installing dependencies…${COLOR_BRIGHT_CYAN}" "${REQUIRED_DEPENDENCIES[@]}" "${NO_COLOR}"
    install_dependencies "${REQUIRED_DEPENDENCIES[@]}"
  elif [[ ${#REQUIRED_DEPENDENCIES[@]} -gt 0 ]]; then
    ohai "Skipping dependency installation…"
    abort "Please install ${YELLOW}${REQUIRED_DEPENDENCIES[*]}${NO_COLOR} manually."
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
      echo "${prefix}${name}=${value}" >>"${file}" && return 0
    fi
  else
    perl -pi -e "/^${name}=.*/d" "${file}" && return 0
  fi
  return 1
}

next_steps() {

  ohai "Next steps:"

  local shell_profile="$(shell_rc_file)"
  local repo_var="export BFD_REPOSITORY=${BFD_REPOSITORY}"
  if [[ -n ${INTERACTIVE:-} ]]; then
    notice "To use the installed functions add this to your scripts:\n${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}source ${BFD_REPOSITORY}/lib/bootstrap.sh${COLOR_RESET}"
    if [[ -f ${shell_profile} ]] && grep -q "${repo_var}" "${shell_profile}"; then
      debug "Environment variable\n${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${repo_var}${COLOR_RESET}\nalready configured in ${shell_profile}"
    else
      start_step "Do you want to add this to your ${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${shell_profile}${COLOR_RESET}${COLOR_BRIGHT_WHITE} now? [Y/n] ${COLOR_RESET}"
      read -r -n 1 -t 120 add_to_shell
      printf "\n"
      if [[ ${add_to_shell:-y} =~ [Yy] ]]; then
        info "Adding environment variable:\n${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${repo_var}${COLOR_RESET}\nto ${shell_profile}"
        set_env_var BFD_REPOSITORY "${BFD_REPOSITORY}" && return 0
      fi
    fi
    info "Run this command in the shell to set the shell-scripts directory:\n   ${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${repo_var}${COLOR_RESET}\n"
    info "Or reload the shell:\n   ${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}source ${shell_profile}${COLOR_RESET}"
  fi

  if [[ -n ${NONINTERACTIVE:-} ]] || [[ -n ${GITHUB_ACTIONS:-} ]]; then
    info "Adding environment variable\n   ${COLOR_BG_BLACK}${COLOR_BRIGHT_BLUE}${repo_var}${COLOR_RESET}"
    set_env_var BFD_REPOSITORY "${BFD_REPOSITORY}"
  fi

}

installer_dependencies
if ! command_exists git && ! downloader_installed; then
  abort "Git, curl, wget, or fetch is required to download the scripts."
fi

install() {
  notice "Installing ${SHELL_SCRIPTS_GITHUB_REPOSITORY}"
  start_step "Validating git user name and email..."
  { execute configure_git && success "Validated git user name and email"; } || failure "Failed to configure git"
  start_step "Creating install directory..."
  { execute create_directories && success "Created install directory"; } || failure "Failed to create directories"
  start_step "Installing shell-scripts..."
  { execute download_shell_scripts && success "Installed shell-scripts"; } || failure "Failed to install shell-scripts"
  next_steps

  success "${STARTING_STAR} Install completed"
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
if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2>/dev/null; then
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
