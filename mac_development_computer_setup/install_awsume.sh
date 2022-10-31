#!/bin/bash
# Path: mac_development_computer_setup/install_awsume.sh
pipx install awsume
pipx inject awsume awsume-console-plugin
awsume-configure --shell zsh
