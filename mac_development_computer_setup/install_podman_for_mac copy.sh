podman machine init -v "${HOME}:${HOME}"
ssh-add ~/.ssh/podman-machine-default  2> /dev/null || true
podman machine set --rootful # Optionally Enable root permissions to allow access to low port numbers 0-1024
sudo "$(brew --prefix podman)/bin/podman-mac-helper" install # Install podman-mac-helper
# Add podman desktop helper, which will allow you to auto start podman at computer startup
sudo -v # Ask for sudo password
PODMAN_DMG_VOLUME="/Volumes/Podman"
PODMAN_APP="/Applications/Podman.app"
PODMAN_TMP_JSON="$(mktemp --suffix ".json")"
PODMAN_GUI_INSTALLER_PATH="${HOME}/Downloads/Podman.dmg"
# if [[ $(uname -p) == 'arm' ]]; then
curl -slL  -o "${PODMAN_TMP_JSON}" 'https://api.github.com/repos/heyvito/podman-macos/releases/latest'
PODMAN_TAG_NAME="$(jq -r '.tag_name' "${PODMAN_TMP_JSON}")"
jq -r '.assets[] | select(.name | test("Podman.dmg")) | .browser_download_url' "${PODMAN_TMP_JSON}" | xargs curl -sSfL -o "${PODMAN_GUI_INSTALLER_PATH}" && echo "Downloaded ${PODMAN_GUI_INSTALLER_PATH}"
rm -f "${PODMAN_TMP_JSON}"
# else
# curl -fLl -o "\${PODMAN_GUI_INSTALLER_PATH}" 'https://github.com/heyvito/podman-macos/releases/download/latest/Podman.dmg'
# fi

echo "Mounting ${PODMAN_GUI_INSTALLER_PATH}"
if hdiutil attach -nobrowse -mountpoint "${PODMAN_DMG_VOLUME}" "${PODMAN_GUI_INSTALLER_PATH}"; then
  echo "Installing Podman GUI"
  if [[ -x "${PODMAN_DMG_VOLUME}/Podman.app" ]]; then
    sudo cp -rf "${PODMAN_DMG_VOLUME}/Podman.app" "${PODMAN_APP%/*}"
    if [[ -x ${PODMAN_APP}   ]]; then
      echo "Installed to ${PODMAN_APP}"
    else
      echo "Failed to install to ${PODMAN_APP}"
    fi
  fi
  sudo xattr -r -d com.apple.quarantine "${PODMAN_APP}"
  open "${PODMAN_APP}"
else
  echo "${PODMAN_GUI_INSTALLER_PATH} could not be mounted - possibly damaged dmg"
fi
echo "Unmounting ${PODMAN_DMG_VOLUME}"
hdiutil detach "${PODMAN_DMG_VOLUME}"
echo "Removing ${PODMAN_GUI_INSTALLER_PATH}"
rm -f "${PODMAN_GUI_INSTALLER_PATH}"

# Configure Podman to run a bash language server in the background in a docker container
# https://github.com/bash-lsp/bash-language-server
# Use port 5023 instead of 5000 as a lot of other services use port 5000
podman container run --rm --name explainshell -p 5023:5000 -d spaceinvaderone/explainshell
EXS_CONTAINER_ID="$(podman container ps -f name=explainshell --format='{{.ID}}' 2> /dev/null)"
# Configure the container to start up at boot
if [[ -n ${EXS_CONTAINER_ID:-} ]]; then
  podman machine ssh "podman generate systemd --new --name \"${EXS_CONTAINER_ID}\" >> \"/etc/systemd/system/${EXS_CONTAINER_ID}.service\""
  : "podman generate systemd --new --name \"${EXS_CONTAINER_ID}\" \>\> \"/etc/systemd/system/${EXS_CONTAINER_ID}.service\""
  podman machine ssh systemctl enable "${EXS_CONTAINER_ID}.service"
  podman machine ssh systemctl start "${EXS_CONTAINER_ID}.service"
else
  echo "Failed to identify explainshell container"
  podman ps container -f name=explainshell
fi

podman machine stop || true
podman machine start
