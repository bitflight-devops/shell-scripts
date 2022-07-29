#!/usr/bin/env bash
# Current Script Directory
if [[ -n ${BFD_REPOSITORY} ]] && [[ -x ${BFD_REPOSITORY} ]]; then
  SCRIPTS_LIB_DIR="${BFD_REPOSITORY}/lib"
fi
if [[ -z ${SCRIPTS_LIB_DIR:-} ]]; then
  if grep -q 'zsh' <<<"$(ps -c -ocomm= -p $$)"; then
    # shellcheck disable=SC2296
    SCRIPTS_LIB_DIR="${0:a:h}"
    SCRIPTS_LIB_DIR="$(cd "${SCRIPTS_LIB_DIR}" >/dev/null 2>&1 && pwd -P)"
  else
    SCRIPTS_LIB_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  fi
fi
export SCRIPTS_LIB_DIR
export BFD_REPOSITORY="${BFD_REPOSITORY:-${SCRIPTS_LIB_DIR%/lib}}"
export ELASTICBEANSTALK_FUNCTIONS_LOADED=1
[[ -z ${SYSTEM_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/system_functions.sh"
[[ -z ${STRING_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/string_functions.sh"
[[ -z ${LOG_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/log_functions.sh"
[[ -z ${GENERAL_UTILITY_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/general_utility_functions.sh"
[[ -z ${GITHUB_CORE_FUNCTIONS_LOADED:-} ]] && source "${SCRIPTS_LIB_DIR}/github_core_functions.sh"

# CLI Utility Functions

apt_fast_dependencies() {
  APPS_TO_INSTALL=()
  if command_exists apt-cache && apt-cache policy ca-certificates | grep -q -v 'Unable to locate package'; then
    APPS_TO_INSTALL+=("ca-certificates")
  fi
  if ! command_exists aria2c; then
    APPS_TO_INSTALL+=("aria2")
  fi
  if ! command_exists curl; then
    APPS_TO_INSTALL+=("curl")
  fi
  if [[ ${#APPS_TO_INSTALL[@]} -ne 0 ]]; then
    run_as_root install_app "${APPS_TO_INSTALL[@]}"
  fi
}

install_apt-fast() {
  if ! command_exists apt-fast; then

    if command_exists debconf-set-selections; then
      run_as_root debconf-set-selections <<<'debconf debconf/frontend select Noninteractive'
    fi

    apt_fast_dependencies
    # Remove the apt-fast script if its older than the current version

    run_as_root downloadFile "https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast" "/usr/local/sbin/apt-fast"
    if [[ ! -f /usr/local/sbin/apt-fast ]]; then
      error "Failed to download apt-fast"
      return 1
    fi
    run_as_root chmod +x /usr/local/sbin/apt-fast
    if [[ ! -f /etc/apt-fast.conf ]]; then
      run_as_root downloadFile "https://raw.githubusercontent.com/ilikenwf/apt-fast/master/apt-fast.conf" "/etc/apt-fast.conf"
    fi
  fi
}

install_ebcli_ubuntu_dependencies() {
  install_apt-fast || true
  if ! command_exists python3; then
    install_app python3
  fi
  if ! command_exists pip3; then
    install_app python3-pip
  fi

  if ! command_exists eb; then
    install_app build-essential zlib1g-dev libssl-dev libncurses-dev \
      libffi-dev libsqlite3-dev libreadline-dev libbz2-dev git \
      python3-venv
  fi
  # python3 -m pip install --user -U pipx
}

add_ebcli_bin_paths() {
  if [[ ${PATH} =~ .local/bin ]]; then
    echo "Path added ${HOME}/.local/bin"
  else
    export PATH="${PATH}:${HOME}/.local/bin"

    if [[ -n ${GITHUB_PATH} ]] && [[ -f ${GITHUB_PATH} ]] && grep -q -v "${HOME}/.local/bin" "${GITHUB_PATH}"; then
      echo "${HOME}/.local/bin" >>"${GITHUB_PATH}"
    fi
  fi
  set_env EB_PACKAGE_PATH "${HOME}/.local/aws-elastic-beanstalk-cli-package"
  if [[ ${PATH} =~ .ebcli-virtual-env/executables ]]; then
    echo "Path added ${HOME}/.ebcli-virtual-env/executables"
  else
    export PATH="${EB_PACKAGE_PATH}/.ebcli-virtual-env/executables:${PATH}"
    if [[ -n ${GITHUB_PATH} ]] && [[ -f ${GITHUB_PATH} ]] && grep -q -v ".ebcli-virtual-env/executables" "${GITHUB_PATH}"; then
      echo "${EB_PACKAGE_PATH}/.ebcli-virtual-env/executables" >>"${GITHUB_PATH}"
    fi
  fi
}

install_eb_cli() {
  info "install_eb_cli: Install EB CLI with python3 $(python3 --version), and python version $(python --version)"

  if ! command_exists git; then
    install_app git
  fi

  if ! command_exists eb || eb --version | grep -q -v 'EB CLI 3'; then

    if ! command_exists pipx; then
      python3 -m pip install --user pipx
    elif ! python3 -m pipx --version >/dev/null 2>&1; then
      python3 -m pip install --user -U pipx
    fi

    if python3 -m pipx ensurepath | grep -q -v "is already in PATH"; then
      if [[ -f ~/.bashrc ]]; then
        source ~/.bashrc
      elif [[ -f ~/.profile ]]; then
        source ~/.profile
      fi
    fi

    add_ebcli_bin_paths

    if ! command_exists virtualenv || virtualenv --version | grep -q -v "virtualenv 2"; then
      python3 -m pipx install virtualenv 2>/dev/null || python3 -m pipx upgrade virtualenv
      add_ebcli_bin_paths
    fi

    if ! command_exists python; then
      run_as_root ln -sf /usr/bin/python3 /usr/bin/python
    fi

    mkdir -p ~/.cache

    if [[ -z ${EB_INSTALLER_PATH:-} ]]; then
      set_env EB_INSTALLER_PATH "${HOME}/.cache/aws-elastic-beanstalk-cli-setup"
    fi

    if [[ ! -d ${EB_INSTALLER_PATH} ]]; then
      git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git "${EB_INSTALLER_PATH}"
    else
      (cd "${EB_INSTALLER_PATH}" && { git pull -f || git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git "${EB_INSTALLER_PATH}"; })
    fi

    add_ebcli_bin_paths

    if [[ -z ${EB_PACKAGE_PATH:-} ]]; then
      set_env EB_PACKAGE_PATH "${HOME}/.local/aws-elastic-beanstalk-cli-package"
    fi

    if [[ ! -d ${EB_PACKAGE_PATH} ]]; then
      mkdir -p "${EB_PACKAGE_PATH}"
    fi

    if ! command_exists eb; then
      python3 "${EB_INSTALLER_PATH}/scripts/ebcli_installer.py" \
        --quiet \
        --hide-export-recommendation \
        --location "${EB_PACKAGE_PATH}"
    fi

  fi
}

eb_run() {
  if ! command_exists eb; then
    install_eb_cli >/dev/null 2>&1
  fi
  if command_exists eb; then
    eb "${@}"
  else
    error "eb command not found"
    exit 1
  fi
}

install_aws_cli() {
  if is_darwin; then
    if command_exists brew; then
      brew install awscli@2
    else
      mkdir -p "${HOME}/Downloads"
      curl -sSlL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "${HOME}/Downloads/AWSCLIV2.pkg"
      cat <<EOF >/tmp/choices.xml
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
      if [[ ${SHELL} == "/bin/zsh" ]]; then
        local shell_profile="${HOME}/.zshrc"
      else
        local shell_profile="${HOME}/.bash_profile"
      fi
      touch "${shell_profile}"
      echo "[[ -d ${HOME}/aws-cli/ ]] && PATH=${HOME}/aws-cli/:${PATH}" >>"${shell_profile}"
      source "${shell_profile}"
    fi
  else
    curl -sSlL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" >/dev/null 2>&1
    (cd /tmp && unzip awscliv2.zip && sudo ./aws/install >/dev/null 2>&1)
  fi
}

aws_run() {
  if ! command_exists aws; then
    install_aws_cli >/dev/null 2>&1 || (echo "Failed to install aws cli" && exit 1)
  fi
  aws "${@}"
}

install_dependencies() {
  install_apt-fast 2>/dev/null || true
  install_app zip unzip curl git jq wget
  install_golang
  install_chamber
}

# Elastic Beanstalk Functions

safe_eb_env_name() {
  local var="${*}"
  sed 's/^[- ]*//g;s/[+_. ]/-/g' <<<"${var}" | tr -s '-'
}

safe_eb_label_name() {
  local var="${*}"
  var="${var//[+]/-}"
  sed 's/^[- ]*//g;s/[+]/-/g' <<<"${var}" | tr -s '-'
}

cname_prefix_by_type() {
  printf '%s' "${APPLICATION_CNAME_PREFIX:-${APPLICATION_NAME}}-${1}${APPLICATION_CNAME_SUFFIX:-}"
}

active_cname_prefix() {
  cname_prefix_by_type active
}

passive_cname_prefix() {
  cname_prefix_by_type passive
}

cname_available() (
  set +o pipefail
  if [[ -z ${1:-} ]]; then
    error "${0}(): missing cname prefix as arg"
    return 2
  fi
  local -r trimmed_arg="$(trim "${1}")"
  if grep -q -i -E "^(active|passive)$" <<<"${trimmed_arg}"; then
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
  local -r name_type="${1}"
  if grep -i -q -v -E "(passive|active)" <<<"${name_type}"; then
    error "${0}(): Invalid name type provided: ${name_type}"
    return 2
  fi
  DEARGS=("--no-paginate" "--output" "text" "--no-include-deleted")
  if [[ -n ${APPLICATION_NAME} ]]; then
    DEARGS+=("--application-name" "${APPLICATION_NAME}")
  fi
  local -r cname_prefix="$(cname_prefix_by_type "${name_type}")"
  local -r CNAME="${cname_prefix}.${REGION:-us-east-1}.elasticbeanstalk.com"
  aws_run elasticbeanstalk describe-environments \
    "${DEARGS[@]}" \
    --query "Environments[?CNAME==\`${CNAME}\` && Status!=\`Terminated\`].[EnvironmentName]" | head -n 1 || true
}

cname_by_environment_name() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    DEARGS=("--no-paginate" "--output" "text" "--no-include-deleted")
    if [[ -n ${APPLICATION_NAME} ]]; then
      DEARGS+=("--application-name" "${APPLICATION_NAME}")
    fi
    aws_run elasticbeanstalk describe-environments \
      "${DEARGS[@]}" \
      --query "Environments[?EnvironmentName==\`${env}\` && Status!=\`Terminated\`].[CNAME]" | head -n 1 || true
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

cname_prefix_by_environment_name() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    cname_by_environment_name "${env}" | cut -d. -f1
  else
    error "${0}(): Environment name not provided"
    return 2
  fi

}

environment_state() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  DEARGS=("--no-paginate" "--output" "text" "--include-deleted")
  if [[ -n ${env} ]]; then
    DEARGS+=("--environment-names" "${env}")
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
  if [[ -n ${APPLICATION_NAME} ]]; then
    DEARGS+=("--application-name" "${APPLICATION_NAME}")
  fi
  aws_run elasticbeanstalk describe-environments \
    --query "Environments[0].Status" \
    "${DEARGS[@]}" | grep -i -E "(Ready|Launching|Updating|Terminating|Terminated)"
}

environment_exists() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    environment_state "${env}" | grep -i -E "(Ready|Launching|Updating|Terminating)"
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

environment_state_ready() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    environment_state "${env}" | grep -i -e "Ready"
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

environment_state_waitable() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    environment_state "${env}" | grep -i -E "(Ready|Launching|Updating)"
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

environment_state_terminating() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    environment_state "${env}" | grep -i "Terminating"
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

environment_state_terminated() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if [[ -n ${env} ]]; then
    environment_state "${env}" | grep -i "Terminated"
  else
    error "${0}(): Environment name not provided"
    return 2
  fi
}

export DEFAULT_WAIT_FOR_READY_TIMEOUT=120
export DEFAULT_WAIT_FOR_READY_RETRY_INTERVAL=5
wait_for_ready() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_READY_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_READY_RETRY_INTERVAL}}"
  local start_time="$(date +%s)"
  local end_time=$((start_time + timeout))
  if [[ -z ${env:-} ]]; then
    error "${0}(): Environment name not provided"
    return 2
  fi
  while STATE=$(environment_state_waitable "${env}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      error "${0}(): FAIL: Environment ${env} status is Terminating or Terminated"
      return 1
    fi

    if [[ ${STATE} == "Ready" ]]; then
      info "${0}(): Environment ${env} status became Ready in $(($(date +%s) - start_time)) seconds"
      return 0
    fi
    sleep "${interval}"
  done

  error "Environment ${env} status not ready after ${timeout} seconds"
  return 1

}

export DEFAULT_WAIT_FOR_TERMINATED_READY_GRACE_TIMEOUT=15
export DEFAULT_WAIT_FOR_TERMINATED_TIMEOUT=120
export DEFAULT_WAIT_FOR_TERMINATED_RETRY_INTERVAL=5
wait_for_terminated() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_TERMINATED_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_TERMINATED_RETRY_INTERVAL}}"
  local -r grace_timeout="${4:-${DEFAULT_WAIT_FOR_TERMINATED_READY_GRACE_TIMEOUT}}"
  local start_time="$(date +%s)"
  local grace_end_time=$((start_time + grace_timeout))
  local end_time=$((start_time + timeout))
  if [[ -z ${env:-} ]]; then
    error '${0}(): Environment name not provided'
    return 2
  fi
  while STATE=$(environment_state_waitable "${env}") && [[ $(date +%s) -lt ${grace_end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_waitable "${env}"; then
    error "${0}(): Environment ${env} status is still 'Ready' after ${grace_timeout} seconds! Did the terminate command get sent?"
    return 3
  fi
  while STATE=$(environment_state_terminating "${env}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_terminated "${env}"; then
    info "${0}(): Environment ${env} status became Terminated in $(($(date +%s) - start_time)) seconds"
    return 0
  fi
  error "${0}(): Environment ${env} status [$(environment_state "${env}")] not terminated after ${timeout} seconds "
  return 1
}

export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_READY_GRACE_TIMEOUT=15
export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_TIMEOUT=120
export DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_RETRY_INTERVAL=5
wait_for_environment_cname_release() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r timeout="${2:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_TIMEOUT}}"
  local -r interval="${3:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_RETRY_INTERVAL}}"
  local -r grace_timeout="${4:-${DEFAULT_WAIT_FOR_ENVIRONMENT_CNAME_RELEASE_READY_GRACE_TIMEOUT}}"

  local start_time="$(date +%s)"
  local grace_end_time=$((start_time + grace_timeout))
  local end_time=$((start_time + timeout))

  if [[ -z ${env:-} ]]; then
    error '${0}(): Environment name not provided'
    return 2
  fi

  local -r current_cname_prefix=$(cname_prefix_by_environment_name "${env}")

  if cname_available "${current_cname_prefix}"; then
    debug "${0}(): cname prefix ${current_cname_prefix} is available"
    return 0
  else
    sleep "${interval}"
  fi

  cname_prefix_by_type "passive"
  while STATE=$(environment_state_waitable "${env}") && [[ $(date +%s) -lt ${grace_end_time} ]]; do
    if cname_available "${current_cname_prefix}"; then
      return 0
    fi
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  while STATE=$(environment_state_terminating "${env}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if cname_available "${current_cname_prefix}"; then
      return 0
    fi
    if [[ -z ${STATE:-} ]]; then
      break
    fi
    sleep "${interval}"
  done
  if environment_state_terminated "${env}" && cname_available "${current_cname_prefix}"; then
    info "${0}(): Environment ${env} status Terminated: cname prefix ${current_cname_prefix} released after $(($(date +%s) - start_time)) seconds"
    return 0
  fi
  error "${0}(): Environment ${env} status [$(environment_state "${env}")]: cname prefix ${current_cname_prefix} not released after ${timeout} seconds"
  return 1
}

wait_for_passive_cname() {
  if [[ -z ${1:-} ]]; then
    local -r env="$(environment_name_by_cname passive)"
    if [[ -z ${env:-} ]]; then
      info "${0}(): No passive environment found"
      return 1
    fi
  else
    local -r env="${1}"
  fi
  wait_for_environment_cname_release "${env}"
}

# withBackoff
## Returns 0 for the data not existing and 1 when the data was successfully retrieved
ebs_pending() (
  set +e
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r infofile="${2:-/tmp/${env}.loginfo.json}"
  aws_run elasticbeanstalk retrieve-environment-info --info-type bundle --query 'sort_by(EnvironmentInfo, &SampleTimestamp)[-1]' --environment-name "${env}" 1>"${infofile}" 2>/dev/null
  local -r r_value=$?
  if [[ ${r_value} -gt 0 ]]; then
    echo "${0}(): error"
    return "${r_value}"
  fi
  jq -r 'if (.Message != null) then 1 else 0 end' "${infofile}"
)

export DEFAULT_WAIT_FOR_EBS_TIMEOUT=15
export DEFAULT_WAIT_FOR_EBS_RETRY_INTERVAL=3
wait_for_ebs() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r loginfo_file="${2:-/tmp/${env}.loginfo.json}"
  local -r timeout="${3:-${DEFAULT_WAIT_FOR_EBS_TIMEOUT}}"
  local -r interval="${4:-${DEFAULT_WAIT_FOR_EBS_RETRY_INTERVAL}}"
  local start_time="$(date +%s)"
  local end_time=$((start_time + timeout))
  if [[ -z ${env:-} ]]; then
    error "${0}(): Environment name not provided"
    return 2
  fi
  while envcount=$(ebs_pending "${env}" "${loginfo_file}") && [[ $(date +%s) -lt ${end_time} ]]; do
    if [[ -z ${envcount:-} ]]; then
      return 1
    fi
    if [[ ${envcount} -gt 0 ]]; then
      debug "${0}(): Waited for ${env} logs for $(($(date +%s) - start_time)) seconds"
      return 0
    fi
    if ! aws_run elasticbeanstalk request-environment-info --info-type bundle --environment-name "${env}" 2>/dev/null; then
      return 1
    fi
    sleep "${interval}"
  done

  error "Environment ${env} eb logs not available after waiting ${timeout} seconds"
  return 1

}

check_if_url_exists() {
  local -r url="${1}"
  curl --output /dev/null --silent --head --fail "${url}"
}

pipe_errors_from_ebs_to_github_actions() {

  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r log_zipfile="${env}.zip"
  local -r log_output_path=".elasticbeanstalk/logs/${env}/"
  if wait_for_ready "${env}" "10" "3"; then
    if [[ ! -f ${log_zipfile} ]]; then
      info "Requesting logs from Elastic Beanstalk's env ${env}: Starting"
      if aws_run elasticbeanstalk request-environment-info --info-type bundle --environment-name "${env}"; then
        info "Requesting logs from Elastic Beanstalk's env ${env}: Success"
        info "Retrieving logs from Elastic Beanstalk's env ${env}: Starting"
        loginfo_file="/tmp/${env}.loginfo.json"
        if wait_for_ebs "${env}" "${loginfo_file}"; then
          local -r url="$(jq -r '.Message' "${loginfo_file}")"
          if curl --fail -sSlL -o "${log_zipfile}" "${url}" 2>/dev/null; then
            mkdir -p "${log_output_path}"
            unzip -o "${log_zipfile}" -d "${log_output_path}" -x "*.gz"
            prints_from_zip "${log_output_path}"
            info "Retrieving logs from Elastic Beanstalk's env ${env}: Success"
            return 0
          else
            debug "${0}(): Cannot download ${url} - possibly doesn't exist"
            info "Retrieving logs from Elastic Beanstalk's env ${env}: Failure"
            return 0
          fi
        else
          if [[ $(jq -r '.EnvironmentInfo | length') -eq 0 ]]; then
            debug "${0}(): Environment ${env} not available to download logs from"
            info "Retrieving logs from Elastic Beanstalk's env ${env}: Failure"
            return 0
          fi
        fi
      else
        info "Requesting logs from Elastic Beanstalk's env ${env}: Failure"
      fi
    else
      info "Printing logs from Elastic Beanstalk's env ${env}: Starting"
      if prints_from_zip "${log_output_path}"; then
        info "Printing logs from Elastic Beanstalk's env ${env}: Success"
      else
        info "Printing logs from Elastic Beanstalk's env ${env}: Failure"
      fi
      return 0
    fi
  else
    info "Elastic Beanstalk's env ${env} status is [$(environment_state "${env}")] which means logs cannot be requested"
  fi

}

stop_current_eb_processes() (
  set -e -o pipefail
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  if aws_run elasticbeanstalk describe-environments --environment-names "${env}" 2>/dev/null | jq -r '.Environments[0].AbortableOperationInProgress' 2>/dev/null | grep -q 'true'; then
    info "Abort environment update for ${env}: Starting"
    if aws_run elasticbeanstalk abort-environment-update --environment-name "${env}"; then
      wait_for_ready "${env}"
      info "Abort environment update for ${env}: Completed"
    else
      error "Abort environment update for ${env}: Failed"
    fi
  fi
)

remove_passive() {
  local -r env="$(environment_name_by_cname passive)"
  if [[ -z ${env:-} ]]; then
    info "${0}(): No passive environment found"
    return 0
  fi
  if environment_state_ready "${env}" 2>/dev/null; then
    pipe_errors_from_ebs_to_github_actions "${env}"
  fi
  eb_run terminate --nohang --force "${env}"
  notice "Passive Environment [${env}] termination signal sent - waiting for CNAME $(passive_cname_prefix) to be released"
  if [[ $1 == "hang" ]]; then
    wait_for_passive_cname "${env}" && notice "Passive Environment [${env}] has released the CNAME $(passive_cname_prefix)"
  fi
}

version_available() {
  aws_run elasticbeanstalk describe-application-versions \
    --application-name "${APPLICATION_NAME}" \
    --version-labels "${1}" \
    --query "ApplicationVersions[0].VersionLabel" \
    --output text | grep -q "${1}"
}

create_application_version() {
  APPLICATION_VERSION_LABEL="${1}"
  DESCRIPTION="${2}"

  if ! version_available "${APPLICATION_VERSION_LABEL}"; then
    notice "Creating application version ${APPLICATION_VERSION_LABEL}"
    eb_run appversion -a "${APPLICATION_NAME}" \
      --label "${APPLICATION_VERSION_LABEL}" \
      --create \
      --staged \
      -m "${DESCRIPTION:-${APPLICATION_VERSION_LABEL}}"
  else
    notice "Application version ${APPLICATION_VERSION_LABEL} already available"
  fi

}

count_environments() {
  aws_run elasticbeanstalk describe-environments \
    --application "${APPLICATION_NAME}" \
    --no-include-deleted \
    --output json \
    --query 'Environments[?Status!=`Terminated`]' | jq -r 'length'
}

environments() {
  if [[ -n ${INSTANCEID} ]]; then
    debug "Environment logs from ${INSTANCEID} for ${ENVIRONMENT_NAME}"
    eb_run logs --stream --instance "${INSTANCEID}" "${ENVIRONMENT_NAME}"
  fi
}

# args:
#   $1: environment name
#   $2: environment creation PID
stream_environment_events() {
  local -r event_path="$(mktemp)"
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r pid="${2:-}"
  if [[ -n ${pid} ]]; then
    debug "Streaming environment logs from PID ${pid} for ${env}"
  else
    debug "Streaming environment logs for ${env}"
  fi
  while ! eb_run events "${env}" >/dev/null 2>&1; do
    if [[ -n ${pid} ]] && ! process_is_running "${pid}"; then
      debug "Streaming environment logs for ${env} stopped. [${pid}] has exited early"
      return 1
    fi
    sleep 1
  done
  eb_run events --follow "${env}" | tee -a "${event_path}" | while read -r line; do

    if grep -q -i -e "(ERROR|Terminating)" <<<"${line}"; then
      step_summary_title "Error creating ${env}"
      step_summary_append "\`${line}\`"
    else
      info "${line}"
    fi
    if [[ -n ${pid} ]] && ! process_is_running "${pid}"; then
      notice "Environment ${env} creation process [${pid}] has completed"
      break
    fi
  done

}

create_environment() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r cname_p="${2:-${CNAME_PREFIX}}"
  local -r timeout="${TIMEOUT_IN_MINUTES:-25}"

  notice "Creating environment ${env} within application ${APPLICATION_NAME}"
  if [[ -z ${DEPLOY_VERSION:-} ]]; then
    eb_run create \
      --cfg "${ENVIRONMENT_CFG}" \
      --cname "${cname_p}" \
      --timeout "${timeout}" \
      "${env}" &
    PID="$!"
  elif version_available "${DEPLOY_VERSION}"; then
    eb_run create \
      --cfg "${ENVIRONMENT_CFG}" \
      --cname "${cname_p}" \
      --timeout "${timeout}" \
      --version "${DEPLOY_VERSION}" \
      "${env}" &
    PID="$!"
  else
    fatal "The version label to be deployed ${DEPLOY_VERSION} is unavailable"
  fi

  # Stream the logs in the background while we wait
  stream_environment_events "${env}" &

  wait "${PID}"

}

deploy_asset() {
  local -r env="${1:-${ENVIRONMENT_NAME}}"
  local -r timeout="${TIMEOUT_IN_MINUTES:-20}"
  debug "Deploying asset to environment ${env} with version ${DEPLOY_VERSION}"
  if [[ -z ${DEPLOY_VERSION:-} ]]; then
    error "The env variable DEPLOY_VERSION is required"
    return 1
  elif version_available "${DEPLOY_VERSION}"; then
    eb_run deploy \
      --version "${DEPLOY_VERSION}" \
      --staged \
      --timeout "${timeout}" \
      "${env}"
  elif [[ -f ${ZIPFILE} ]]; then
    eb_run deploy \
      --label "${DEPLOY_VERSION}" \
      --staged \
      --timeout "${timeout}" \
      "${env}"
  else
    error "The version label to be deployed ${DEPLOY_VERSION} is unavailable, and there is no built zipfile to deploy"
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
  [[ -n ${REGION} ]] && EB_ARGS+=("--region=${REGION}")
  [[ -n ${EC2_KEYNAME} ]] && EB_ARGS+=("--keyname=${EC2_KEYNAME}")

  eb_run init "${EB_ARGS[@]}" "${APPLICATION_NAME}"

}

eb_load_config() {
  debug "eb_load_config: Load Config from file to EB: ${ENVIRONMENT_CFG}"
  if [[ -z ${ENVIRONMENT_CFG:-} ]]; then
    error "eb_load_config: requires an ENVIRONMENT_CFG environment variable to exist"
    return 1
  fi
  eb_run config put "${ENVIRONMENT_CFG}"

}