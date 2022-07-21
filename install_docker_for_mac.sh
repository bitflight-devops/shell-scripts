#!/bin/sh

cat <<EOF > ~/docker_installer.sh
#!/usr/bin/env bash
DOCKER_INSTALLER_PATH="$HOME/Downloads/Docker.dmg"
if [[ \$(uname -p) == 'arm' ]]; then
  echo "Downloading Docker.dmg for M1 Chip"
  curl -fLl -o "\${DOCKER_INSTALLER_PATH}" 'https://desktop.docker.com/mac/main/arm64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-arm64'
else
  echo "Downloading Docker.dmg for Intel Chip"
  curl -fLl -o "\${DOCKER_INSTALLER_PATH}" 'https://desktop.docker.com/mac/main/amd64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-amd64'
fi

echo "Mounting Docker.dmg"
if hdiutil attach "\${DOCKER_INSTALLER_PATH}"; then
  echo "Installing Docker"
  /Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license
else
  echo "Docker.dmg could not be mounted - possibly damaged dmg"
fi
echo "Unmounting Docker.dmg"
hdiutil detach /Volumes/Docker
echo "Removing Docker.dmg"
rm -f "\${DOCKER_INSTALLER_PATH}"
EOF
chmod +x ~/docker_installer.sh
sudo ~/docker_installer.sh
