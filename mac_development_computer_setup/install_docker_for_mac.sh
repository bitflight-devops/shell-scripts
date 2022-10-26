#!/usr/bin/env bash
# Path: mac_development_computer_setup/install_docker_for_mac.sh
## <script src="https://get-fig-io.s3.us-west-1.amazonaws.com/readability.js"></script>
## <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/themes/prism-okaidia.min.css" rel="stylesheet" />
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-core.min.js" data-manual></script>
## <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.16.0/components/prism-bash.min.js"></script>
## <style>body {color: #272822; background-color: #272822; font-size: 0.8em;} </style>

# Create Variables
## INSTALL_USER: the username for automatically setting up docker group
INSTALL_USER="${SUDO_USER:-${USER}}"
## INSTALL_SCRIPT_PATH: the path to the temp installer script
INSTALL_SCRIPT_PATH="$(mktemp -d)/docker_installer.sh" || failed "$0 failed making temp directory. Exiting"
## DOCKER_DMG_PATH: Where the dmg is downloaded to
DOCKER_DMG_PATH="${HOME}/Downloads/Docker.dmg"

# Create Functions
## failed(): failure message handler function
failed() {
  echo "FAILED: $*" >&2
  exit 1
}
FAILED_FUNC="$(declare -f failed)"

## download_docker_to(): downloads docker dmg to specified path
download_docker_to() {
  local dmg_file="$1"
  if [[ ! -f "${dmg_file}" ]]; then
    echo "Downloading Docker installer..."
    if [[ $(uname -p) == 'arm' ]]; then
      echo "Downloading Docker.dmg for M1 Chip"
      curl -fLl -o "${dmg_file}" 'https://desktop.docker.com/mac/main/arm64/Docker.dmg'
    else
      echo "Downloading Docker.dmg for Intel Chip"
      curl -fLl -o "${dmg_file}" 'https://desktop.docker.com/mac/main/amd64/Docker.dmg'
    fi
  fi
}
DOWNLOAD_FUNC="$(declare -f download_docker_to)"

## install_docker_as_1_from_2(): installs docker from specified dmg file as specified user
install_docker_as_1_from_2() {
  local user="$1"
  local dmg_file="$2"
  echo "Mounting Docker.dmg"
  if hdiutil attach "${dmg_file}"; then
    echo "Installing Docker"
    /Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license --user="${user}"
  else
    failed "${dmg_file} could not be mounted - possibly a broken dmg file, please try again"
  fi
  echo "Unmounting Docker.dmg"
  hdiutil detach /Volumes/Docker
}
INSTALL_FUNC="$(declare -f install_docker_as_1_from_2)"

## cleanup_files(): removes the temp files created
cleanup_files() {
  if [[ -f "${DOCKER_DMG_PATH}" ]]; then
    echo "Removing ${DOCKER_DMG_PATH}"
    rm -f "${DOCKER_DMG_PATH}"
  fi
  if [[ -f "${INSTALL_SCRIPT_PATH}" ]]; then
    echo "Removing ${INSTALL_SCRIPT_PATH}"
    rm -f "${INSTALL_SCRIPT_PATH}"
  fi
}

# Trap to cleanup files when script exits
trap cleanup_files SIGINT SIGTERM EXIT

# Create a script like this so that we can run it as root
cat << EOF > "${INSTALL_SCRIPT_PATH}"
#!/usr/bin/env bash
# Add the functions to our temporary script
${FAILED_FUNC}
${DOWNLOAD_FUNC}
${INSTALL_FUNC}
# Run the functions
download_docker_to "${DOCKER_DMG_PATH}"
install_docker_as_1_from_2 "${INSTALL_USER}" "${DOCKER_DMG_PATH}"
EOF

# Make the script executable
chmod +x "${INSTALL_SCRIPT_PATH}"
# Install as root
sudo "${INSTALL_SCRIPT_PATH}"

# ------------------------------------------
#   Notes
# ------------------------------------------
#
# This script contains hidden JavaScript which is used to improve
# readability in the browser (via syntax highlighting, etc), right-click
# and "View source" of this page to see the entire bash script!
# -- style code from https://fig.io/install
