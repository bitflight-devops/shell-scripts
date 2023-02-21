#!/usr/bin/env bash

##########################################################
##### Lookup Current Script Directory

command_exists() { command -v "$@" > /dev/null 2>&1; }

if [[ -z ${SCRIPTS_LIB_DIR:-}   ]]; then
  LC_ALL=C
  export LC_ALL
  set +e
  read -r -d '' GET_LIB_DIR_IN_ZSH <<- 'EOF'
	0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
	0="${${(M)0:#/*}:-$PWD/$0}"
	SCRIPTS_LIB_DIR="${0:a:h}"
	SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" > /dev/null 2>&1 && pwd -P)"
	EOF
  set -e
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
    [[ ${whichshell:-} == "zsh"   ]]
  }
  if command_exists zsh && [[ ${whichshell:-} == "zsh"   ]]; then
    # We are running in zsh
    eval "${GET_LIB_DIR_IN_ZSH}"
  else
    # we are running in bash/sh
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
  fi
fi

# End Lookup Current Script Directory
##########################################################

: "${BFD_REPOSITORY:=${SCRIPTS_LIB_DIR%/lib}}"
: "${ELASTICBEANSTALK_FUNCTIONS_LOADED:=1}"

[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"
[[ -z ${GENERAL_UTILITY_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/general_utility_functions.sh"
[[ -z ${REMOTE_UTILITY_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/remote_utility_functions.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"

# CLI Utility Functions
getProperty() {
  PROP_KEY="$1"
  PROPERTY_FILE="$2"
  grep "${PROP_KEY}" "${PROPERTY_FILE}" | awk -F "=" '{print $2}' | sed "s/[\ '\"]//g"
}

apt_fast_dependencies() {
  APPS_TO_INSTALL=()
  if ! app_installed "ca-certificates"; then
    APPS_TO_INSTALL+=("ca-certificates")
  fi
  if ! command_exists aria2c; then
    APPS_TO_INSTALL+=("aria2")
  fi
  if ! command_exists curl; then
    APPS_TO_INSTALL+=("curl")
  fi
  if [[ ${#APPS_TO_INSTALL[@]} -ne 0 ]]; then
    install_app "${APPS_TO_INSTALL[@]}"
  fi
}

install_apt-fast() {
  if ! command_exists apt-fast; then

    if command_exists debconf-set-selections; then
      run_as_root debconf-set-selections <<< 'debconf debconf/frontend select Noninteractive'
    fi

    apt_fast_dependencies
    # Remove the apt-fast script if its older than the current version
    run_as_root mkdir -p /usr/local/sbin
    run_as_root downloadFile "https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast" "/usr/local/sbin/apt-fast" "true"
    if [[ ! -f /usr/local/sbin/apt-fast ]]; then
      error "Failed to download apt-fast"
      return 1
    fi
    run_as_root chmod +x /usr/local/sbin/apt-fast
    if [[ ! -f /etc/apt-fast.conf ]]; then
      run_as_root downloadFile "https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast.conf" "/etc/apt-fast.conf" "true"
    fi
  fi
}

latest_solution_stack_coretto11() {
  trim "$(aws elasticbeanstalk list-available-solution-stacks | jq -r '.SolutionStacks | map(select( contains("running Corretto 11"))) | .[0]' 2> /dev/null || echo "corretto-11")"
}

latest_solution_stack_tomcat85() {
  trim "$(aws elasticbeanstalk list-available-solution-stacks | jq -r '.SolutionStacks | map(select(contains("Tomcat 8.5 Corretto 11"))) | .[0]' 2> /dev/null || echo "tomcat-8.5-corretto-11")"
}

add_ebcli_bin_paths() {
  # Use add_to_path from system_functions
  save_in_shellrc="${GITHUB_ACTIONS+"yes"}"
  add_to_path "${HOME}/.local/bin" "${save_in_shellrc:-}"
  add_to_path "${HOME}/.local/aws-elastic-beanstalk-cli-package" "${save_in_shellrc:-}"
  add_to_path "${HOME}/.ebcli-virtual-env/executables" "${save_in_shellrc:-}"
  add_to_path "${HOME}/.local/aws-elastic-beanstalk-cli-package/.ebcli-virtual-env/executables" "${save_in_shellrc:-}"
}

install_ebcli_ubuntu_dependencies() {
  add_ebcli_bin_paths
  MISSING_APPS=()

  if ! command_exists python3; then
    MISSING_APPS+=("python3")
  fi
  if ! command_exists pip3; then
      MISSING_APPS+=("python3-pip")
  fi
  if [[ $(uname) == "Linux" ]] && command_exists apt; then
    if ! ubuntu_package_installed "python3-venv"; then
      MISSING_APPS+=("python3-venv")
    fi
    if ! ubuntu_package_installed git && ! command_exists git; then
      MISSING_APPS+=("git")
    fi
    if ! ubuntu_package_installed build-essential; then
      MISSING_APPS+=("build-essential")
    fi
    if ! ubuntu_package_installed libssl-dev; then
      MISSING_APPS+=("libssl-dev")
    fi
    if ! ubuntu_package_installed libffi-dev; then
      MISSING_APPS+=("libffi-dev")
    fi
    if ! ubuntu_package_installed zlib1g-dev; then
      MISSING_APPS+=("zlib1g-dev")
    fi
    if ! ubuntu_package_installed libncurses-dev; then
      MISSING_APPS+=("libncurses-dev")
    fi
    if ! ubuntu_package_installed libbz2-dev; then
      MISSING_APPS+=("libbz2-dev")
    fi
    if ! ubuntu_package_installed libsqlite3-dev; then
      MISSING_APPS+=("libsqlite3-dev")
    fi
    if ! ubuntu_package_installed libreadline-dev; then
      MISSING_APPS+=("libreadline-dev")
    fi
  fi
  if [[ ${#MISSING_APPS[@]} -gt 0   ]]; then
    { command_exists apt && install_apt-fast; } || true
    install_app "${MISSING_APPS[@]}"
  fi
  if ! command_exists pipx; then
    python3 -m pip install --user -U pipx
    python3 -m pipx ensurepath
  fi

}

install_eb_cli() {
  mkdir -p ~/.cache ~/.local
  install_ebcli_ubuntu_dependencies
  info "Install EB CLI with python3 $(python3 --version || true)"
  [[ -z ${HOME-} ]] && export HOME="$(cd ~/ && pwd -P)"

  if [[ ! -f "${HOME}/.local/aws-elastic-beanstalk-cli-package/.ebcli-virtual-env/bin/eb" ]]; then
    REINSTALL=true
  elif ! command_exists eb; then
    REINSTALL=true
  elif eb --version | grep -q -v 'EB CLI 3'; then
    REINSTALL=true
  fi
  if [[ -n ${REINSTALL-}   ]]; then

    if ! command_exists pipx; then
      debug "Install pipx:\n$(python3 -m pip install --user pipx)"
    elif ! python3 -m pipx --version > /dev/null 2>&1; then
      debug "Upgrade pipx:\n$(python3 -m pip install --user -U pipx)"
    fi

    if python3 -m pipx ensurepath 2> /dev/null | grep -q -v "is already in PATH"; then
      if [[ -f ~/.bashrc ]]; then
        source ~/.bashrc
      elif [[ -f ~/.profile ]]; then
        source ~/.profile
      fi
    fi

    if ! command_exists virtualenv || virtualenv --version | grep -q -v "virtualenv 2"; then
      debug "Install virtualenv:\n$(python3 -m pipx install --system-site-packages virtualenv 2> /dev/null || python3 -m pipx --system-site-packages -f upgrade virtualenv)"
    fi

    if ! command_exists python; then
      run_as_root ln -sf /usr/bin/python3 /usr/bin/python || true
    fi

    if [[ -z ${EB_INSTALLER_PATH:-} ]]; then
      set_env EB_INSTALLER_PATH "${HOME}/.cache/aws-elastic-beanstalk-cli-setup"
    fi

    if [[ ! -d ${EB_INSTALLER_PATH} ]]; then
      mkdir -p "${EB_INSTALLER_PATH}"
      git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git "${EB_INSTALLER_PATH}"
    else
      git -C "${EB_INSTALLER_PATH}" reset --hard HEAD || true
      if ! git -C "${EB_INSTALLER_PATH}" pull -f; then
        rm -rf "${EB_INSTALLER_PATH}"
        git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git "${EB_INSTALLER_PATH}"
      fi
    fi

    if [[ -z ${EB_PACKAGE_PATH:-} ]]; then
      set_env EB_PACKAGE_PATH "${HOME}/.local/aws-elastic-beanstalk-cli-package"
    fi

    if [[ ! -d ${EB_PACKAGE_PATH} ]]; then
      mkdir -p "${EB_PACKAGE_PATH}"
    fi

    if [[ ! -f "${HOME}/.local/aws-elastic-beanstalk-cli-package/.ebcli-virtual-env/bin/eb" ]] || ! command_exists eb; then
      rm -rf "${HOME}/.local/aws-elastic-beanstalk-cli-package"
      python3 "${EB_INSTALLER_PATH}/scripts/ebcli_installer.py" \
        --quiet \
        --hide-export-recommendation \
        --location "${EB_PACKAGE_PATH}"
    fi

  fi
  if ! eb --version > /dev/null 2>&1 || eb --version | grep -q -v 'EB CLI 3'; then
    error "EB CLI not installed"
    exit 1
  fi
}

unzip_file() {
  if ! command_exists unzip; then
    install_app unzip > /dev/null 2>&1 || true
  fi
  unzip "$@"
}

eb_run() {
  if ! command_exists eb; then
    install_eb_cli > /dev/null 2>&1
  fi
  if command_exists eb; then
    eb "${@}"
  else
    error "eb command not found"
    exit 1
  fi
}

install_aws_cli() {
  if command_exists brew; then
    brew install awscli@2
  elif is_darwin; then
    mkdir -p "${HOME}/Downloads"
    curl -sSlL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "${HOME}/Downloads/AWSCLIV2.pkg"
    cat << EOF > /tmp/choices.xml
    <?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key>
      <string>customLocation</string>
      <key>attributeSetting</key>
      <string>${HOME}</string>
      <key>choiceIdentifier</key>
      <string>default</string>
    </dict>
  </array>
</plist>
EOF
    /usr/sbin/installer -pkg "${HOME}/Downloads/AWSCLIV2.pkg" \
      -target CurrentUserHomeDirectory \
      -applyChoiceChangesXML /tmp/choices.xml
    rm -f "${HOME}/Downloads/AWSCLIV2.pkg"
    add_to_path "${HOME}/aws-cli/" "true"
  else
    downloadFile "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -p).zip" "/tmp/awscliv2.zip"
    unzip_file -qq -u -o /tmp/awscliv2.zip -d /tmp && run_as_root /tmp/aws/install
  fi
}

aws_run() {
  if ! command_exists aws; then
    if ! install_aws_cli > /tmp/install_aws_cli.log 2>&1; then
      error "Failed to install aws cli" && info "$(cat /tmp/install_aws_cli.log)"
      exit 1
    fi
  fi
  aws "${@}"
}
golang_arch() {
  if [[ $# -gt 0 ]]; then
    local arch="$1"
  else
    local arch="$(uname -m)"
  fi
  case "${arch}" in
    x86_64)
      echo "amd64"
      ;;
    armv6l)
      echo "armv6l"
      ;;
    armv7l)
      echo "armv7"
      ;;
    aarch64)
      echo "arm64"
      ;;
    i686 | i386)
      echo "386"
      ;;
    *)
      error "Unsupported architecture $(uname -m)"
      exit 1
      ;;
  esac
}
golang_os() {
  if [[ $# -gt 0 ]]; then
    local os="$1"
  else
    local os="$(uname -s)"
  fi
  case "${os}" in
    Linux | linux)
      echo "linux"
      ;;
    Darwin | darwin)
      echo "darwin"
      ;;
    FreeBSD | freebsd)
      echo "freebsd"
      ;;
    *)
      error "Unsupported OS $(uname -s)"
      exit 1
      ;;
  esac
}

add_user() {
  if [[ $(id -un) != 'root' ]]; then
    error "you must run add_user as root"
    return 1
  fi
  local user_name="${1}"
  if command_exists yum; then
    if ! command_exists useradd; then
      yum install -qq -y shadow-utils util-linux
    fi
  fi
  useradd "${user_name}"

}

get_list_of_docker_tags() {
  source "${DIR}"/get-app-name.sh
  local -r DOCKER_IMAGE_NAME="${APPLICATION_PREFIX}"
  aws_run ecr list-images --repository-name "${DOCKER_IMAGE_NAME}" --filter tagStatus=TAGGED --region us-east-1
}

function install_chamber() {
  # is chamber already installed?
  if ! command_exists chamber; then
    debug_log "Installing Chamber"
    install_chamber_version > /dev/null 2>&1 && debug_log "Chamber now installed"
  else
    debug_log "Chamber installed already"
  fi
}

function install_package_to_path() {
  local current_file="${1}"
  local install_path="${2}"
  if [[ -f ${current_file}   ]]; then
    local install_dir="$(dirname "${install_path}")"
    mkdir -p "${install_dir}"
    rm -f "${install_path}"
    mv "${temp_file_location}" "${install_path}"
    add_to_path "${install_dir}"
    chmod +x "${install_path}"
    info "Installed ${current_file} to ${install_path}"
  else
    fatal "Failed to install ${current_file} to ${install_path}"
  fi
}

install_chamber_version() {
  if ! command_exists chamber; then
    if command_exists brew; then
      brew install chamber && return 0
    fi
    local url_base="https://github.com/segmentio/chamber/releases/download"
    local url_version="${1:-v2.10.12}"
    local url_platform="$(golang_os)"
    local url_arch="$(golang_arch)"

    local temp_file_location=$(mktemp -u)
    local url="${url_base}/${url_version}/chamber-${url_version}-${url_platform}-${url_arch}"
    downloadFile "${url}" "${temp_file_location}"

    if root_available && [[ ${PREFER_USERSPACE:-} != "true"   ]]; then
      local install_path="/usr/local/bin/chamber"
      $(root_available) install_package_to_path "${temp_file_location}" "${install_path}"
    else
      local install_path="${HOME}/.local/bin/chamber"
      install_package_to_path "${temp_file_location}" "${install_path}"
    fi
  fi
}

function install_golang() {
  if ! command_exists go; then
    if command_exists brew; then
      brew install go
    else
      local url_base="https://golang.org/dl"
      local url_version="${GOLANG_VERSION:=1.19.3}"
      local url_platform="$(golang_os)-$(golang_arch)"
      local package_name="go${url_version}.${url_platform}.tar.gz"
      local temp_file_location=$(mktemp -d || true)
      local url="${url_base}/${package_name}"
      local package_path="${temp_file_location:=/tmp}/${package_name}"
      if [[ ! -f ${package_path}   ]]; then
        downloadFile "${url}" "${package_path}" "true" || fatal "Failed to download golang"
      fi

      if root_available && [[ ${PREFER_USERSPACE:-} != "true"   ]]; then
        local install_path="/usr/local"
        $(root_available) bash -c "mkdir -p '${install_path}' && rm -rf '${install_path}/go' && tar -C '${install_path}' -xzf '${package_path}'" || fatal "Failed to extract ${package_path} to ${install_path}"
      else
        local install_path="${HOME}/.local"
        bash -c "mkdir -p '${install_path}' && rm -rf '${install_path}/go' && tar -C '${install_path}' -xzf '${package_path}'" || fatal "Failed to extract ${package_path} to ${install_path}"
      fi

      rm -f "${package_path}"
      add_to_path "${install_path}/go/bin" "true"
      which go
      squash_output go version || fatal "golang install failed"
      add_to_path "$(go env GOPATH)" "true"
    fi
  fi
}

install_dependencies() {
  install_apt-fast 2> /dev/null || true
  install_app zip unzip curl git jq wget
  install_golang
  install_chamber
}

essential_variable() {
  local variable_name="${1:-}"
  shift
  local skip_list="${*:-}"
  if ! test -v "${variable_name}" || [[ -z ${!variable_name}   ]]; then
    declare -a caller_stack_messages
    local caller_stack_count=0
    for func in "${FUNCNAME[@]}"; do
      if [[ ${func} == "${FUNCNAME[0]}"   ]]; then
        continue
      fi
      if [[ -n ${skip_list}   ]] && [[ ${skip_list} == *"${func}"*   ]]; then
        continue
      fi
      ((caller_stack_count++))
      if [[ ${caller_stack_count} -gt 1 ]]; then
        caller_stack_messages+=("called by ${func}")
      else
        caller_stack_messages+=("in ${func}")
      fi
    done
    if [[ -n ${BASH_SOURCE:-}   ]]; then
      caller_stack_messages+=("in script ${BASH_SOURCE[1]}")
    fi
    printf -v backtrace '%s, ' "${caller_stack_messages[@]}"
    fatal "The variable ${variable_name} was needed ${backtrace%, }"
  fi
}
# Elastic Beanstalk Functions

current_environment_name() {
  ## Get the current environment name
  essential_variable "ENVIRONMENT_NAME" # Validate the variable exists
  echo "${ENVIRONMENT_NAME}"
}

current_app_name() {
  ## Get the current application name
  essential_variable "APPLICATION_NAME" # Validate the variable exists
  echo "${APPLICATION_NAME}"
}

safe_eb_env_name() {
  local var="${*}"
  local current_ts="$(date +%s || true)" # fallback to seconds since epoch
  local md5_hash=$(md5sum <<< "${var}" || echo "${RANDOM:-${current_ts}}")
  local label="$(sed 's/^[- ]*//g;s/[+_. ]/-/g' <<< "${var}" | tr -s '-')"
  if [[ ${#label} -gt 30 ]]; then
    label="${label:0:30}"
    label="${label}-${md5_hash:0:10}"
  fi
  echo "${label}"
}

safe_eb_label_name() {
  local var="${*}"
  var="${var//[+]/-}"
  local current_ts="$(date +%s || true)" # fallback to seconds since epoch
  local md5_hash="$(md5sum <<< "${var}" || echo "${RANDOM:-${current_ts}}")"
  local label="$(sed 's/^[- ]*//g;s/[+]/-/g' <<< "${var}" | tr -s '-')"
  if [[ ${#label} -gt 80 ]]; then
    label="${label:0:80}"
    label="${label}-${md5_hash:0:18}"
  fi
  echo "${label}"

}

cname_prefix_by_type() {

  printf '%s' "${APPLICATION_CNAME_PREFIX:-$(current_app_name)}-${1}${APPLICATION_CNAME_SUFFIX:-}"
}

active_cname_prefix() {
  cname_prefix_by_type active
}

passive_cname_prefix() {
  cname_prefix_by_type passive
}

cname_available() (
  set +o pipefail
  if [[ $# -eq 0 ]]; then
    error "${0}(): missing cname prefix as arg"
    return 2
  fi
  local -r trimmed_arg="$(trim "${1}")"
  if grep -q -i -E "^(active|passive)$" <<< "${trimmed_arg}"; then
    local -r cname_prefix="$(cname_prefix_by_type "${trimmed_arg}")"
  else
    local -r cname_prefix="${trimmed_arg}"
  fi

  if aws_run elasticbeanstalk check-dns-availability \
    --cname-prefix "${cname_prefix}" \
    --output text \
    --query "Available" | grep -q -i -e 'true'; then
    echo 'true' && return 0
  else
    echo 'false' && return 1
  fi
)

environment_name_by_cname() {
  local -r name_type="${1?'cname prefix of type active or passive required'}"
  if grep -i -q -v -E "(passive|active)" <<< "${name_type}"; then
    error "${0}(): Invalid name type provided: ${name_type}"
    return 2
  fi
  DEARGS=("--no-paginate" "--output" "text" "--no-include-deleted")
  if [[ -n ${APPLICATION_NAME:-}   ]]; then
    DEARGS+=("--application-name" "${APPLICATION_NAME}")
  fi
  local -r cname_prefix="$(cname_prefix_by_type "${name_type}")"
  local -r CNAME="${cname_prefix}.${REGION:-us-east-1}.elasticbeanstalk.com"
  aws_run elasticbeanstalk describe-environments \
    "${DEARGS[@]}" \
    --query "Environments[?CNAME==\`${CNAME}\` && Status!=\`Terminated\`].[EnvironmentName]" | head -n 1 || true
}

cname_by_environment_name() {
  local -r env_name="${1:-$(current_environment_name)}"
  if [[ -n ${env_name+x} ]]; then
    DEARGS=("--no-paginate" "--output" "text" "--no-include-deleted")
    if [[ -n ${APPLICATION_NAME:-} ]]; then
      DEARGS+=("--application-name" "${APPLICATION_NAME}")
    fi
    aws_run elasticbeanstalk describe-environments \
      "${DEARGS[@]}" \
      --query "Environments[?EnvironmentName==\`${env_name}\` && Status!=\`Terminated\`].[CNAME]" | head -n 1 || true
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

cname_prefix_by_environment_name() {
  local -r env_name="${1:-$(current_environment_name)}"
  cname_by_environment_name "${env_name}" | cut -d. -f1
}

environment_state() {
  local -r env_name="${1:-$(current_environment_name)}"
  DEARGS=("--no-paginate" "--output" "text" "--include-deleted")
  DEARGS+=("--environment-names" "${env_name}")

  if [[ -n ${APPLICATION_NAME:-} ]]; then
    DEARGS+=("--application-name" "${APPLICATION_NAME}")
  fi
  aws_run elasticbeanstalk describe-environments \
    --query "Environments[0].Status" \
    "${DEARGS[@]}" | grep -i -E "(Ready|Launching|Updating|Terminating|Terminated)"
}

environment_exists() {
  local -r env_name="${1:-$(current_environment_name)}"
  environment_state "${env_name}" | grep -i -E "(Ready|Launching|Updating|Terminating)"
}

environment_state_ready() {
  local -r env_name="${1:-$(current_environment_name)}"
  environment_state "${env_name}" | grep -i -e "Ready"
}

environment_state_waitable() {
  local -r env_name="${1:-$(current_environment_name)}"
  environment_state "${env_name}" | grep -i -E "(Ready|Launching|Updating)"
}

environment_state_terminating() {
  local -r env_name="${1:-$(current_environment_name)}"
  environment_state "${env_name}" | grep -i "Terminating"
}

environment_state_terminated() {
  local -r env_name="${1:-$(current_environment_name)}"
    environment_state "${env_name}" | grep -i "Terminated"
}

export DEFAULT_WAIT_FOR_READY_TIMEOUT=120
export DEFAULT_WAIT_FOR_READY_RETRY_INTERVAL=5
wait_for_ready() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_READY_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_READY_RETRY_INTERVAL}}"
  local start_time="$(date +%s)"
  local end_time=$((start_time + timeout))

  while STATE=$(environment_state_waitable "${env_name}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      error "${0}(): FAIL: Environment ${env_name} status is Terminating or Terminated"
      return 1
    fi

    if [[ ${STATE} == "Ready" ]]; then
      info "${0}(): Environment ${env_name} status became Ready in $(($(date +%s) - start_time)) seconds"
      return 0
    fi
    sleep "${interval}"
  done

  error "Environment ${env_name} status not ready after ${timeout} seconds"
  return 1

}

export DEFAULT_WAIT_FOR_TERMINATED_READY_GRACE_TIMEOUT=15
export DEFAULT_WAIT_FOR_TERMINATED_TIMEOUT=120
export DEFAULT_WAIT_FOR_TERMINATED_RETRY_INTERVAL=5
wait_for_terminated() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_TERMINATED_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_TERMINATED_RETRY_INTERVAL}}"
  local -r grace_timeout="${4:-${DEFAULT_WAIT_FOR_TERMINATED_READY_GRACE_TIMEOUT}}"
  local start_time="$(date +%s)"
  local grace_end_time=$((start_time + grace_timeout))
  local end_time=$((start_time + timeout))

  while STATE=$(environment_state_waitable "${env_name}") && [[ $(date +%s) -lt ${grace_end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_waitable "${env_name}"; then
    error "${0}(): Environment ${env_name} status is still 'Ready' after ${grace_timeout} seconds! Did the terminate command get sent?"
    return 3
  fi
  while STATE=$(environment_state_terminating "${env_name}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_terminated "${env_name}"; then
    info "${0}(): Environment ${env_name} status became Terminated in $(($(date +%s) - start_time)) seconds"
    return 0
  fi
  error "${0}(): Environment ${env_name} status [$(environment_state "${env_name}")] not terminated after ${timeout} seconds "
  return 1
}

export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_READY_GRACE_TIMEOUT=15
export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_TIMEOUT=120
export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_RETRY_INTERVAL=5
wait_for_environment_cname_release() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_RETRY_INTERVAL}}"
  local -r grace_timeout="${4:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_READY_GRACE_TIMEOUT}}"

  local start_time="$(date +%s)"
  local grace_end_time=$((start_time + grace_timeout))
  local end_time=$((start_time + timeout))

  local -r current_cname_prefix=$(cname_prefix_by_environment_name "${env_name}")

  if cname_available "${current_cname_prefix}"; then
    debug "${0}(): cname prefix ${current_cname_prefix} is available"
    return 0
  else
    sleep "${interval}"
  fi

  cname_prefix_by_type "passive"
  while STATE=$(environment_state_waitable "${env_name}") && [[ $(date +%s) -lt ${grace_end_time} ]]; do
    if cname_available "${current_cname_prefix}"; then
      return 0
    fi
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  while STATE=$(environment_state_terminating "${env_name}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if cname_available "${current_cname_prefix}"; then
      return 0
    fi
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_terminated "${env_name}" && cname_available "${current_cname_prefix}"; then
    info "${0}(): Environment ${env_name} status Terminated: cname prefix ${current_cname_prefix} released after $(($(date +%s) - start_time)) seconds"
    return 0
  fi
  error "${0}(): Environment ${env_name} status [$(environment_state "${env_name}")]: cname prefix ${current_cname_prefix} not released after ${timeout} seconds"
  return 1
}

wait_for_passive_cname() {
  local env_name="${1:-$(environment_name_by_cname passive)}"

  if [[ -z ${env_name:-} ]]; then
    warning "${0}: No passive environment found"
    return 1
  fi

  wait_for_environment_cname_release "${env_name}"
}

# withBackoff
## Returns 0 for the data not existing and 1 when the data was successfully retrieved
retrieve_ebs_pending_logs() (
  set +e
  local -r env_name="${1:-$(current_environment_name)}"
  local -r infofile="${2:-/tmp/${env_name}.loginfo.json}"
  aws_run elasticbeanstalk retrieve-environment-info --info-type bundle --query 'sort_by(EnvironmentInfo, &SampleTimestamp)[-1]' --environment-name "${env_name}" 1> "${infofile}" 2> /dev/null
  local -r r_value=$?
  if [[ ${r_value} -gt 0 ]]; then
    echo "${0}(): error"
    return "${r_value}"
  fi
  jq -r 'if (.Message != null) then 1 else 0 end' "${infofile}"
)

export DEFAULT_WAIT_FOR_EBS_TIMEOUT=15
export DEFAULT_WAIT_FOR_EBS_RETRY_INTERVAL=3
wait_for_ebs_logs() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r loginfo_file="${2:-/tmp/${env_name}.loginfo.json}"
  local -r timeout="${3:-${DEFAULT_WAIT_FOR_EBS_TIMEOUT}}"
  local -r interval="${4:-${DEFAULT_WAIT_FOR_EBS_RETRY_INTERVAL}}"
  local start_time="$(date +%s)"
  local end_time=$((start_time + timeout))
  local env_available

  while env_available=$(retrieve_ebs_pending_logs "${env_name}" "${loginfo_file}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ ${env_available} -gt 0 ]]; then
      debug "${0}(): Waited for ${env_name} logs for $(($(date +%s) - start_time)) seconds"
      return 0
    fi
    sleep "${interval}"
  done

  error "Environment ${env_name} eb logs not available after waiting ${timeout} seconds"
  return 1

}

check_if_url_exists() {
  local -r url="${1}"
  curl --output /dev/null --silent --head --fail "${url}"
}

pipe_errors_from_ebs_to_github_actions() {

  local -r env_name="${1:-$(current_environment_name)}"
  local -r log_zipfile="${env_name}.zip"
  local -r log_output_path=".elasticbeanstalk/logs/${env_name}/"
  if wait_for_ready "${env_name}" "10" "3"; then
    if [[ ! -f ${log_zipfile} ]]; then
      info "Requesting logs from Elastic Beanstalk's env ${env_name}: Starting"
      if aws_run elasticbeanstalk request-environment-info --info-type bundle --environment-name "${env_name}"; then
        info "Requesting logs from Elastic Beanstalk's env ${env_name}: Success"
        info "Retrieving logs from Elastic Beanstalk's env ${env_name}: Starting"
        loginfo_file="/tmp/${env_name}.loginfo.json"
        if wait_for_ebs_logs "${env_name}" "${loginfo_file}"; then
          local -r url="$(jq -r '.Message' "${loginfo_file}")"
          if curl --fail -sSlL -o "${log_zipfile}" "${url}" 2> /dev/null; then
            mkdir -p "${log_output_path}"
            debug "UNZIP log files:\n$(unzip -o "${log_zipfile}" -d "${log_output_path}" -x "*.gz")"
            print_logs_from_zip "${log_output_path}"
            info "Retrieving logs from Elastic Beanstalk's env ${env_name}: Success"
            return 0
          else
            debug "${0}(): Cannot download ${url} - possibly doesn't exist.\n$(cat "${loginfo_file}")"
            info "Retrieving logs from Elastic Beanstalk's env ${env_name}: Failure"
            return 0
          fi
        else
          if ! jq -r '.Message' "${loginfo_file}" > /dev/null 2>&1; then
            debug "${0}(): Environment ${env_name} not available to download logs: [${loginfo_file}]\n$(jq '.' "${loginfo_file}")"
            info "Retrieving logs from Elastic Beanstalk's env ${env_name}: Failure"
            return 0
          fi
        fi
      else
        info "Requesting logs from Elastic Beanstalk's env ${env_name}: Failure"
      fi
    else
      info "Printing logs from Elastic Beanstalk's env ${env_name}: Starting"
      if print_logs_from_zip "${log_output_path}"; then
        info "Printing logs from Elastic Beanstalk's env ${env_name}: Success"
      else
        info "Printing logs from Elastic Beanstalk's env ${env_name}: Failure"
      fi
      return 0
    fi
  else
    debug "Environment state:\n$(elasticbeanstalk describe-environments --environment-names "${env_name}")"
    info "Elastic Beanstalk's env ${env_name} status is [$(environment_state "${env_name}")] which means logs cannot be requested"
  fi

}

stop_current_eb_processes() (
  set -e -o pipefail
  local -r env_name="${1:-$(current_environment_name)}"
  if aws_run elasticbeanstalk describe-environments --environment-names "${env_name}" 2> /dev/null | jq -r '.Environments[0].AbortableOperationInProgress' 2> /dev/null | grep -q 'true'; then
    info "Abort environment update for ${env_name}: Starting"
    if aws_run elasticbeanstalk abort-environment-update --environment-name "${env_name}"; then
      wait_for_ready "${env_name}"
      info "Abort environment update for ${env_name}: Completed"
    else
      error "Abort environment update for ${env_name}: Failed"
    fi
  fi
)

remove_passive() {
  local -r waitforcomplete="${1:-false}"
  local -r env_name="${2:-$(environment_name_by_cname passive)}"
  if [[ -z ${env_name:-} ]]; then
    info "${0}(): No passive environment found"
    return 0
  fi
  if environment_state_ready "${env_name}" 2> /dev/null; then
    pipe_errors_from_ebs_to_github_actions "${env_name}"
  fi
  eb_run terminate --nohang --force "${env_name}"
  notice "Passive Environment [${env_name}] termination signal sent - waiting for CNAME $(passive_cname_prefix) to be released"
  if [[ ${waitforcomplete} == "hang" ]] || [[ ${waitforcomplete} == "true" ]]; then
    wait_for_passive_cname "${env_name}" && notice "Passive Environment [${env_name}] has released the CNAME $(passive_cname_prefix)"
  fi
}

version_available() {
  local -r version_label="${1}"
  aws_run elasticbeanstalk describe-application-versions \
    --application-name "$(current_app_name)" \
    --version-labels "${version_label}" \
    --query "ApplicationVersions[0].VersionLabel" \
    --output text | grep -q "${version_label}"
}

create_application_version() {
  local version_label="${1:-}"
  local version_description="${2:-}"
  local app_name="$(current_app_name)"
  if [[ ${#version_label} -gt 100   ]]; then
    error "Version label cannot be longer than 100 characters"
    return 1
  fi
  if ! version_available "${version_label}"; then
    notice "Creating application version ${version_label}"
    eb_run appversion -a "${app_name}" \
      --label "${version_label}" \
      --create \
      --staged \
      -m "${version_description:-${version_label}}"
  else
    notice "Application version ${version_label} already available"
  fi

}

count_environments() {
  local app_name="$(current_app_name)"

  aws_run elasticbeanstalk describe-environments \
    --application "${app_name}" \
    --no-include-deleted \
    --output json \
    --query 'Environments[?Status!=`Terminated`]' | jq -r 'length'
}

environments() {
  local -r env_name="${1:-$(current_environment_name)}"
  if [[ -n ${INSTANCEID:-} ]]; then
    debug "Environment logs from ${INSTANCEID} for ${env_name}"
    eb_run logs --stream --instance "${INSTANCEID}" "${env_name}"
  fi
}

# args:
#   $1: environment name
#   $2: environment creation PID
stream_environment_events() {
  local -r event_path="$(mktemp)"
  local -r env_name="${1:-$(current_environment_name)}"
  local -r pid="${2:-}"
  if [[ -n ${pid:-} ]]; then
    debug "Streaming environment logs from PID ${pid} for ${env_name}"
  else
    debug "Streaming environment logs for ${env_name}"
  fi
  while ! eb_run events "${env_name}" > /dev/null 2>&1; do
    if [[ -n ${pid:-} ]] && ! process_is_running "${pid}"; then
      debug "Streaming environment logs for ${env_name} stopped. [${pid}] has exited early"
      return 1
    fi
    sleep 1
  done
  eb_run events --follow "${env_name}" | tee -a "${event_path}" | while read -r line; do

    if grep -q -i -e "(ERROR|Terminating)" <<< "${line}"; then
      step_summary_title "Error creating ${env_name}"
      step_summary_append "\`${line}\`"
    else
      info "${line}"
    fi
    if [[ -n ${pid:-} ]] && ! process_is_running "${pid}"; then
      notice "Environment ${env_name} creation process [${pid}] has completed"
      break
    fi
  done

}

create_environment() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r cname_p="${2:-${CNAME_PREFIX}}"
  local -r timeout="${TIMEOUT_IN_MINUTES:-25}"
  local version_label=${VERSION_ID:-${VERSION_LABEL:-${DEPLOY_VERSION:-}}} # DEPLOY_VERSION is deprecated

  notice "Creating environment ${env_name} within application ${APPLICATION_NAME}"
  if [[ -z ${version_label} ]] && [[ -n ${ASSET_PATH+x} || -n ${ZIPFILE+x}     ]]; then
    eb_run create \
      --cfg "${ENVIRONMENT_CFG}" \
      --cname "${cname_p}" \
      --timeout "${timeout}" \
      "${env_name}" &
    PID="$!"
  elif version_available "${version_label}"; then
    eb_run create \
      --cfg "${ENVIRONMENT_CFG}" \
      --cname "${cname_p}" \
      --timeout "${timeout}" \
      --version "${version_label}" \
      "${env_name}" &
    PID="$!"
  else
    fatal "The version label to be deployed ${version_label} is unavailable"
  fi

  # Stream the logs in the background while we wait
  stream_environment_events "${env_name}" &

  wait "${PID}"

}

deploy_asset() {
  local -r env_name="${1:-$(current_environment_name)}"
  local -r timeout="${TIMEOUT_IN_MINUTES:-20}"
  local version_label=${VERSION_ID:-${VERSION_LABEL:-${DEPLOY_VERSION:-}}} # DEPLOY_VERSION is deprecated
  debug "Deploying asset to environment ${env_name} with version ${version_label}"
  if [[ -z ${version_label:-} ]]; then
    error "The env variable VERSION_LABEL or VERSION_ID is required"
    return 1
  elif version_available "${version_label}"; then
    eb_run deploy \
      --version "${version_label}" \
      --staged \
      --timeout "${timeout}" \
      "${env_name}"
  elif [[ -f ${ZIPFILE} ]]; then
    eb_run deploy \
      --label "${version_label}" \
      --staged \
      --timeout "${timeout}" \
      "${env_name}"
  else
    error "The version label to be deployed ${version_label} is unavailable, and there is no built zipfile to deploy"
    return 1
  fi
}

eb_init() {
  debug "eb_init: Init EB CLI"
  if [[ -z ${EB_PLATFORM:-} ]]; then
    error "eb_init: requires an EB_PLATFORM environment variable to exist"
    return 1
  fi
  EB_ARGS=("--platform=${EB_PLATFORM}")
  [[ -n ${REGION:-} ]] && EB_ARGS+=("--region=${REGION}")
  [[ -n ${EC2_KEYNAME} ]] && EB_ARGS+=("--keyname=${EC2_KEYNAME}")

  eb_run init "${EB_ARGS[@]}" "${APPLICATION_NAME}"

}

eb_load_config() {
  local -r env_config_name="${1:-${ENVIRONMENT_CFG:-}}"
  debug "eb_load_config: Load Config from file to EB: ${env_config_name}"
  if [[ -z ${env_config_name:-} ]]; then
    error "eb_load_config: requires an env_config_name environment variable to exist"
    return 1
  fi
  eb_run config put "${env_config_name}"

}
