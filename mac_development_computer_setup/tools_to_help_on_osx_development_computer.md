# Tools and Shell Improvements for MacOS Development Computer

```bash
#!/usr/bin/env bash

#--------------------------------------------------------------------------------------------------
```

## OSX

### Install Docker

<https://docs.docker.com/desktop/install/mac-install/>

Or paste [this script](install_docker_for_mac.sh) into your terminal:

```sh
cat <<EOF > ~/docker_installer.sh
#!/usr/bin/env bash
DOCKER_INSTALLER_PATH="$HOME/Downloads/Docker.dmg"
if [[ $(uname -p) == 'arm' ]]; then
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
```

### Install [Homebrew](https://brew.sh/)

```sh
xcode-select --install 2>/dev/null || true # Install Xcode command line tools
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sudo sh -c "compaudit | xargs chown -R \"$(whoami)\"" # Fix permissions for Homebrew
sudo sh -c "compaudit | xargs chmod go-w" # Fix permissions on all files in /usr/local

```

### Create convenient shell functions

```sh

## Create helper shell functions
command_exists() {
  command -v "$@" >/dev/null 2>&1
}

reshim() {
  # Reshim ASDF if it is installed
  if command_exists asdf; then
    asdf reshim
  fi
  # Reshim jenv if it is installed
  if command_exists jenv; then
    jenv reshim
  fi
}

slurp() {
  if [[ -p /dev/stdin ]]; then
    cat -
  fi
  if [[ "$#" -ne 0 ]]; then
    echo "$@"
  fi
}
get_tool_info() {
  brew info --json "$1" | jq -r '.[] | "brew_apps+=(\""+(.name)+"\") # "+(.desc)'
}
brew_tap_individually() {
  NONINTERACTIVE=1 xargs -t -P1 -I'{}' -n1 bash -c "brew tap -q --repair ${*} '{}' || true"
}
brew_install_individually() {
  NONINTERACTIVE=1 xargs -t -P1 -I'{}' -n1 bash -c "brew install -q -f ${*} '{}' || true"
}
brew_info_individually() {
  info_func="$(declare -f get_tool_info)"
  NONINTERACTIVE=1 xargs -P5 -I'{}' -n1 bash -c "${info_func};get_tool_info '{}' || true"
}
brew_tap_all() {
  taps=($(slurp "$@"))
  brew_tap_individually <<< "${taps[*]}"
}

brew_install_all() {
  # Install all packages supplied via stdin, and as arguments
  # Attempt to install all packages, even if some fail
  formula=($(slurp "$@"))
  if [[ "${#formula[@]}" -eq 0 ]]; then
    echo "No formulae supplied to brew_install_all" >&2
    return 1
  fi
  if grep -q -- "--cask" <<<"${formula[*]}"; then
    iscask="--cask"
    formula=(${formula[@]/${iscask}})
    echo "Installing ${formula[*]} as casks"
  else
    echo "Installing ${formula[*]}"
  fi
  # 2>/dev/null
  NONINTERACTIVE=1 brew install -f ${iscask-} "${formula[@]}" || \
    brew_install_individually ${iscask-} <<< "${formula[*]}"
}



```

## Setup Brew Taps - alternate software repositories

```sh
# Bring brew up to date
NONINTERACTIVE=1 brew update --force --quiet
NONINTERACTIVE=1 brew upgrade --force --quiet

# Connect to Third Party Brew Repositories
#### Uses the `brew_tap_all` shell function created above
brew_tap_all << EOF
aws/tap
codacy/tap
dart-lang/dart
hashicorp/tap
homebrew/bundle
homebrew/cask
homebrew/cask-fonts
homebrew/cask-versions
homebrew/core
homebrew/services
jtyr/repo
lucagrulla/tap
mutagen-io/mutagen
sass/sass
EOF
```

## Install Runtimes

### Python First

```sh
## Drop python 2.7 support
brew uninstall --force --quiet python2 2>/dev/null || true
if [ -x /usr/bin/python ]; then
  if [[ $(/usr/bin/python --version 2>&1) == Python\ 2.7* ]]; then
    echo "Old python version found at /usr/bin/python"
    echo "You probably should upgrade your OS to remove this"
    echo "If you are on a Mac, you can try running 'softwareupdate --install --all'"
  fi
fi

install_global_python() {
  brew_install_all python3 python-tk python@3.10 python-tk@3.10
  pip install --upgrade "setuptools<60" wheel
  python -m ensurepip --upgrade
  pip install --upgrade pip  2>&1 | grep -v "DEPRECATION:"
  pip install --upgrade pipx 2>&1 | grep -v "DEPRECATION:"
  # Install setuptools under version 60.0.0 to avoid breaking a few dependencies like numba

}
install_global_python

# Python utilities
pipx install emoji-fzf


```

### Install Java Runtimes

```sh
### The adoptopenjdk/openjdk tap is deprecated use homebrew/cask-versions instead
brew untap adoptopenjdk/openjdk || true

brew_install_all --cask temurin temurin8 temurin11 temurin18 # Java JDK's
```

## Install [meta-package-manager](https://kdeldycke.github.io/meta-package-manager/install.html) (mpm)

```sh
pipx install meta-package-manager || true
```

## ZSH Frameworks

### [Zim](https://zimfw.sh)
```sh
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
```

### [Alf](https://github.com/psyrendust/alf)

```sh
curl -sSL https://raw.githubusercontent.com/psyrendust/alf/master/bootstrap/baseline.zsh | zsh
```


## Collect and Install all the packages

```sh
## Install Shell Utilities
brew_apps+=("antigen") # Plugin manager for zsh, inspired by oh-my-zsh and vundle
brew_apps+=("zsh") # UNIX shell (command interpreter)
brew_apps+=("iterm2") # Terminal Gui


## Install compression libraries
brew_apps+=("zstd") # Zstandard is a real-time compression algorithm
brew_apps+=("xz") # General-purpose data compression with high compression ratio
brew_apps+=("brotli") # Generic-purpose lossless compression algorithm by Google
brew_apps+=("lz4") # Extremely Fast Compression algorithm
brew_apps+=("pigz") # Parallel gzip
brew_apps+=("p7zip") # 7-Zip (high compression file archiver) implementation
brew_apps+=("zip") # Compression and file packaging/archive utility
brew_apps+=("unzip") # Extraction utility for .zip compressed archives
brew_apps+=("gnu-tar") # GNU version of the tar archiving utility

## install general build tools
brew_apps+=("cmake") # Cross-platform make
brew_apps+=("make") # Utility for directing compilation
brew_apps+=("pkg-config") # Manage compile and link flags for libraries
brew_apps+=("ninja") # Small build system for use with gyp or CMake
brew_apps+=("autoconf") # Automatic configure script builder
brew_apps+=("automake") # Tool for generating GNU Standards-compliant Makefiles
brew_apps+=("libtool") # Generic library support script
brew_apps+=("gdb") # GNU debugger
brew_apps+=("valgrind") # Dynamic analysis tools (memory, debug, profiling)
brew_apps+=("binutils") # GNU binary tools for native development
brew_apps+=("gcc") # GNU compiler collection

## Install Java build tools
brew_apps+=("gradle") # Open-source build automation tool based on the Groovy and Kotlin DSL
brew_apps+=("maven") # Java-based project management

## Install Python build tools
brew_apps+=("pyenv") # Python version management
brew_apps+=("poetry") # Python package management tool

## Install Node build tools
brew_apps+=("deno") # Secure runtime for JavaScript and TypeScript
brew_apps+=("node") # Platform built on V8 to build network applications
brew_apps+=("yarn") # JavaScript package manager

## Install Programming Languages
brew_apps+=("go") # Go programming environment
brew_apps+=("rust") # Systems programming language
brew_apps+=("ruby") # Powerful, clean, object-oriented scripting language
brew_apps+=("groovy") # Java-based scripting language
brew_apps+=("python") # Interpreted, interactive, object-oriented programming language
brew_apps+=("lua") # Powerful, lightweight programming language
brew_apps+=("perl") # Practical Extraction and Report Language
brew_apps+=("haskell-stack") # Cross-platform program for developing Haskell projects
brew_apps+=("erlang") # Concurrent, real-time, distributed functional language
brew_apps+=("elixir") # Functional metaprogramming aware language built on Erlang VM

## Install data querying tools
brew_apps+=("jp") # Command-line interface to JMESPath, a query language for JSON
brew_apps+=("yq") # Process YAML documents from the CLI
brew_apps+=("csvkit") # Suite of command-line tools for converting to and working with CSV
brew_apps+=("jq") # Lightweight and flexible command-line JSON processor

## Install database tools
brew_apps+=("sqlite") # Command-line interface for SQLite

## CLI string manipulation tools
brew_apps+=("grep") # GNU grep, egrep and fgrep
brew_apps+=("awk") # Text processing scripting language
brew_apps+=("gnu-sed") # GNU implementation of the famous stream editor

## Install CLI monitoring tools
brew_apps+=("watch") # Executes a program periodically, showing output fullscreen
brew_apps+=("htop") # Interactive process viewer
brew_apps+=("glances") # Cross-platform monitoring tool
brew_apps+=("iftop") # Display an interface's bandwidth usage
brew_apps+=("nethogs") # Net top tool
brew_apps+=("ncdu") # Disk usage analyzer with an ncurses interface
brew_apps+=("dstat") # Versatile resource statistics tool
brew_apps+=("iotop") # Top-like UI for I/O usage
brew_apps+=("bmon") # Text-mode bandwidth monitor
brew_apps+=("procs") # A modern replacement for ps written in Rust

## Install base linux tools
brew_apps+=("coreutils") # GNU File, Shell, and Text utilities
brew_apps+=("findutils") # Collection of GNU find, xargs, and locate
brew_apps+=("gawk") # GNU awk utility
brew_apps+=("gnu-indent") # C code prettifier
brew_apps+=("gnu-sed") # GNU implementation of the famous stream editor
brew_apps+=("gnu-tar") # GNU version of the tar archiving utility
brew_apps+=("gnu-which") # GNU implementation of which utility
brew_apps+=("gnupg") # GNU Pretty Good Privacy (PGP) package
brew_apps+=("grep") # GNU grep, egrep and fgrep
brew_apps+=("gzip") # Popular GNU data compression program
brew_apps+=("gnutls") # GNU Transport Layer Security (TLS) Library
brew_apps+=("guile") # GNU Ubiquitous Intelligent Language for Extensions

## Install remote shell tools
brew_apps+=("screen") # Terminal multiplexer with VT100/ANSI terminal emulation
brew_apps+=("tmux") # Terminal multiplexer

## Install web cli tools
brew_apps+=("httpie") # User-friendly cURL replacement (command-line HTTP client)
brew_apps+=("ca-certificates") # Mozilla CA certificate store
brew_apps+=("curl") # Get a file from an HTTP, HTTPS or FTP server
brew_apps+=("wget") # Internet file retriever
brew_apps+=("links") # Lynx-like WWW browser that supports tables, menus, etc.
brew_apps+=("http-prompt") # An interactive command-line HTTP client featuring autocomplete and syntax highlighting
brew_apps+=("aria2") # Lightweight multi-protocol & multi-source command-line download utility
brew_apps+=("curlie") # Modern command line HTTP client featuring intuitive UI, JSON support, syntax highlighting, wget-like downloads, extensions, etc.
brew_apps+=("http") # Curl for Humans
brew_apps+=("graphqurl") # Curl for GraphQL with autocomplete, subscriptions and GraphiQL


## Install networking tools
brew_apps+=("nmap") # Port scanning utility for large networks
brew_apps+=("telnet") # User interface to the TELNET protocol
brew_apps+=("netcat") # Utility for managing network connections
brew_apps+=("socat") # SOcket CAT: netcat on steroids
brew_apps+=("mtr") # 'traceroute' and 'ping' in a single tool
brew_apps+=("bind") # Implementation of the DNS protocols
brew_apps+=("hping") # Command-line oriented TCP/IP packet assembler/analyzer
brew_apps+=("httperf") # Tool for measuring webserver performance
brew_apps+=("libssh") # C library SSHv1/SSHv2 client and server protocols
brew_apps+=("libssh2") # C library implementing the SSH2 protocol
brew_apps+=("lftp") # Sophisticated file transfer program
brew_apps+=("iperf") # Tool to measure maximum TCP and UDP bandwidth
brew_apps+=("nghttp2") # HTTP/2 C Library
brew_apps+=("ngrep") # Network grep
brew_apps+=("nmap") # Port scanning utility for large networks
brew_apps+=("nettle") # Low-level cryptographic library
brew_apps+=("openldap") # Open source suite of directory software
brew_apps+=("openssl@3") # Cryptography and SSL/TLS Toolkit

## Install cli text reading tools
brew_apps+=("exa") # Modern replacement for 'ls'
brew_apps+=("bat") # Clone of cat(1) with syntax highlighting and Git integration
brew_apps+=("ccat") # Like cat but displays content with syntax highlighting

## File comparison tools
brew_apps+=("diffutils") # File comparison utilities
brew_apps+=("wdiff") # Display word differences between text files

## Directory navigation tools
brew_apps+=("fzf") # Command-line fuzzy finder written in Go
brew_apps+=("exa") # Modern replacement for 'ls'
brew_apps+=("ripgrep") # Search tool like grep and The Silver Searcher
brew_apps+=("fd") # Simple, fast and user-friendly alternative to find
brew_apps+=("tree") # Display directories as trees (with optional color/HTML output)
brew_apps+=("zoxide") # Shell extension to navigate your filesystem faster
brew_apps+=("broot") # A new way to see and navigate directory trees
brew_apps+=("fd") # A simple, fast and user-friendly alternative to find

## CLI Help and Documentation tools
brew_apps+=("cheat") # Create and view interactive cheat sheets for *nix commands
brew_apps+=("tldr") # Simplified and community-driven man pages
brew_apps+=("navi") # An interactive cheatsheet tool for the command-line

## CLI Recording tools
brew_apps+=("asciinema") # Record and share terminal sessions
brew_apps+=("ttygif") # Converts a ttyrec file into gif files


## Disk usage and storage allocation tools
brew_apps+=("ncdu") # NCurses Disk Usage
brew_apps+=("diskus") # Minimal, fast alternative to 'du -sh'
brew_apps+=("dust") # More intuitive version of du in rust
brew_apps+=("duf") # Disk Usage/Free Utility - a better 'df' alternative
brew_apps+=("exa") # Modern replacement for 'ls'

## CLI text editing tools
brew_apps+=("vim") # Vi 'workalike' with many additional features
brew_apps+=("neovim") # Vim-fork focused on extensibility and agility
brew_apps+=("emacs") # GNU Emacs text editor
brew_apps+=("nano") # Pico editor clone with enhancements
brew_apps+=("micro") # Modern and intuitive terminal-based text editor
brew_apps+=("kakoune") # Modal code editor inspired by vim
brew_apps+=("kak-lsp") # Language Server Protocol client for Kakoune

# Docker and Container Development Tools
brew_apps+=("mutagen-compose") # Compose with Mutagen integration
brew_apps+=("mutagen") # Fast file synchronization and network forwarding for remote development
brew_apps+=("hadolint") # Smarter Dockerfile linter to validate best practices

## GitHub Actions and CLI tools
brew_apps+=("act") # Run your GitHub Actions locally 🚀
brew_apps+=("actionlint") # Static checker for GitHub Actions workflow files
brew_apps+=("gh") # GitHub command-line tool
brew_apps+=("hub") # Add GitHub support to git on the command-line

## Font Configuration tools
brew_apps+=("fontconfig") # XML-based font configuration API for X Windows
brew_apps+=("freetype") # Software library to render fonts
brew_apps+=("harfbuzz") # OpenType text shaping engine
brew_apps+=("graphite2") # Smart font renderer for non-Roman scripts

## Fonts
brew_apps+=("font-hack-nerd-font") # Hack Nerd Font (Hasklig)
brew_apps+=("font-hack-nerd-font-mono") # Hack Nerd Font Mono (Hasklig)
brew_apps+=("font-hack-nerd-font-complete") # Hack Nerd Font Complete (Hasklig)
brew_apps+=("font-dejavu-sans-mono-nerd-font") # DejaVu Sans Mono Nerd Font


## Tools for managing and configuring MacOS
brew_apps+=("chezmoi") # Manage your dotfiles across multiple machines, securely
brew_apps+=("macos-defaults") # Set macOS defaults from the command-line
brew_apps+=("mas") # Mac App Store command-line interface
brew_apps+=("mackup") # Keep your application settings in sync (OS X/Linux)
brew_apps+=("cask") # Homebrew Cask provides a friendly homebrew-style CLI workflow for the administration of Mac applications distributed as binaries

## Formatting and Linting tools
brew_apps+=("perltidy") # Perl source code pretty printer
brew_apps+=("shellcheck") # Shell script analysis tool
brew_apps+=("shfmt") # Shell script formatter
brew_apps+=("yamllint") # Linter for YAML files
brew_apps+=("yamale") # YAML schema validator
brew_apps+=("google-java-format") # Reformat Java source code to comply with Google Java Style
brew_apps+=("prettier") # Opinionated code formatter
brew_apps+=("prettierd") # Prettier daemon for editors
brew_apps+=("prettier-plugin-sh") # Prettier plugin for shell scripts
brew_apps+=("prettier-plugin-xml") # Prettier plugin for XML
brew_apps+=("prettier-plugin-yaml") # Prettier plugin for YAML
brew_apps+=("prettier-plugin-toml") # Prettier plugin for TOML
brew_apps+=("prettier-plugin-json") # Prettier plugin for JSON
brew_apps+=("prettier-plugin-markdown") # Prettier plugin for Markdown

## Benchparking and profiliing Tools
brew_apps+=("hyperfine") # A command-line benchmarking tool
brew_apps+=("hey") # HTTP load generator, ApacheBench (ab) replacement, formerly rakyll/hey
brew_apps+=("vegeta") # HTTP load testing tool and library. It's over 9000!
brew_apps+=("wrk") # Modern HTTP benchmarking tool
brew_apps+=("bombardier") # Fast cross-platform HTTP benchmarking tool written in Go
brew_apps+=("boom") # HTTP(S) load testing tool
brew_apps+=("gatling") # Modern load testing as code

## Image manipulation tools
brew_apps+=("jasper") # Library for manipulating JPEG-2000 images
brew_apps+=("libiconv") # Conversion library

## Software Libraries
brew_apps+=("libffi") # Foreign Function Interface library
brew_apps+=("libtiff") # TIFF library and utilities
brew_apps+=("libxml2") # GNOME XML library
brew_apps+=("libssh2") # C library implementing the SSH2 protocol
brew_apps+=("libpng") # Library for manipulating PNG images
brew_apps+=("libxslt") # C XSLT library for GNOME
brew_apps+=("libyaml") # YAML Parser
brew_apps+=("ncurses") # Text-based UI library

## Application Version Management Tools
brew_apps+=("nvm") # Manage multiple Node.js versions
brew_apps+=("rbenv") # Ruby version manager
brew_apps+=("pyenv") # Simple Python version management
brew_apps+=("topgrade") # Upgrade everything
brew_apps+=("asdf") # Extendable version manager with support for Ruby, Node.js, Elixir, Erlang & more
brew_apps+=("tfenv") # Terraform version manager

## Application Configuration Management Tools
brew_apps+=("brew-cask-completion") # Fish completion for brew cask


## Window Management tools
brew_apps+=("yabai") # A tiling window manager for macOS based on binary space partitioning
brew_apps+=("skhd") # Simple hotkey daemon for macOS
brew_apps+=("chunkwm") # Tiling window manager for macOS based on plugin architecture
brew_apps+=("kwm") # Tiling window manager for macOS based on plugin architecture
brew_apps+=("spectacle") # Move and resize windows with ease
brew_apps+=("rectangle") # Move and resize windows in macOS using keyboard

## MacOS Application Development Tools
brew_apps+=("xcbeautify") # Little beautifier tool for xcodebuild
brew_apps+=("xcodegen") # Generate your Xcode project from a spec file and your folder structure
brew_apps+=("carthage") # Decentralized dependency manager for Cocoa
brew_apps+=("xctool") # Drop-in replacement for xcodebuild with a few extra features
brew_apps+=("swiftlint") # Tool to enforce Swift style and conventions
brew_apps+=("swiftgen") # Swift code generator for assets, storyboards, Localizable.strings, …
brew_apps+=("swiftformat") # Formatting tool for reformatting Swift code


## CLI Git Tools
brew_apps+=("git-lfs") # Git extension for versioning large files
brew_apps+=("git-flow") # Extensions to follow Vincent Driessen's branching model
brew_apps+=("git-delta") # Syntax-highlighting pager for git and diff output
brew_apps+=("git") # Distributed revision control system
brew_apps+=("git-extras") # Small git utilities
brew_apps+=("gitui") # Blazing fast terminal-ui for git written in rust
brew_apps+=("tig") # Text interface for Git repositories
brew_apps+=("gh") # GitHub command-line tool
brew_apps+=("hub") # Add GitHub support to git on the command-line
brew_apps+=("ghq") # Remote repository management made easy

## Install Cloud Utilities
brew_apps+=("azure-cli") # Microsoft Azure CLI 2.0
brew_apps+=("aws-elasticbeanstalk") # Client for Amazon Elastic Beanstalk web service
brew_apps+=("pulumi") # Cloud native development platform
brew_apps+=("terraform") # Tool to build, change, and version infrastructure
brew_apps+=("terraform-docs") # Tool to generate documentation from Terraform modules
brew_apps+=("terragrunt") # Thin wrapper for Terraform e.g. for locking state
brew_apps+=("helmfile") # Deploy Kubernetes Helm Charts
brew_apps+=("kubeseal") # Kubernetes controller and tool for one-way encrypted Secrets
brew_apps+=("kustomize") # Template-free customization of Kubernetes YAML manifests
brew_apps+=("helm") # Kubernetes package manager
brew_apps+=("aws-sam-cli") # AWS SAM CLI 🐿 is a tool for local development and testing of Serverless applications
brew_apps+=("aws-iam-authenticator") # Use AWS IAM credentials to authenticate to Kubernetes
brew_apps+=("aws-okta") # Authenticate with AWS using your Okta credentials
brew_apps+=("aws-vault") # Securely store and access AWS credentials in development environments
brew_apps+=("awscli") # Official Amazon AWS command-line interface
brew_apps+=("terraform") # Tool to build, change, and version infrastructure
brew_apps+=("packer") # Tool for creating identical machine images for multiple platforms
brew_apps+=("terragrunt") # Thin wrapper for Terraform e.g. for locking state
brew_apps+=("kops") # Production Grade K8s Installation, Upgrades, and Management
brew_apps+=("kubectx") # Tool that can switch between kubectl contexts easily and create aliases
brew_apps+=("k9s") # Kubernetes CLI To Manage Your Clusters In Style!
brew_apps+=("awless") # A Mighty CLI for AWS
brew_apps+=("gcloud") # Google Cloud SDK
brew_apps+=("gcloud-completion") # Bash completion for gcloud
brew_apps+=("docker-credential-helper-ecr") # Docker Credential Helper for Amazon ECR




```


### brew bundle install

TODO: Add section here with details about how to install the brew bundle



## Install Other Utilities (Not in Homebrew)

```zsh
npm install -g tldr # Manuals and HowTo's
curl -fsSL https://git.io/shellspec | sh -s -- --yes # Shell Check for running tests against shell scripts
```

### Initialise Utilities (TODO: remove podman setup, it's not needed)

```zsh
podman machine init -v "${HOME}:${HOME}"
ssh-add ~/.ssh/podman-machine-default  2>/dev/null || true
podman machine set --rootful # Optionally Enable root permissions to allow access to low port numbers 0-1024
sudo "$(brew --prefix podman)/bin/podman-mac-helper" install # Install podman-mac-helper
# Add podman desktop helper, which will allow you to auto start podman at computer startup
sudo -v # Ask for sudo password
PODMAN_DMG_VOLUME="/Volumes/Podman"
PODMAN_APP="/Applications/Podman.app"
PODMAN_TMP_JSON="$(mktemp --suffix ".json")"
PODMAN_GUI_INSTALLER_PATH="$HOME/Downloads/Podman.dmg"
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
    if [[ -x "${PODMAN_APP}" ]]; then
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
EXS_CONTAINER_ID="$(podman container ps -f name=explainshell --format='{{.ID}}' 2>/dev/null)"
# Configure the container to start up at boot
if [[ -n ${EXS_CONTAINER_ID:-} ]]; then
podman machine ssh "podman generate systemd --new --name \"${EXS_CONTAINER_ID}\" >> \"/etc/systemd/system/${EXS_CONTAINER_ID}.service\""
"podman generate systemd --new --name \"${EXS_CONTAINER_ID}\" \>\> \"/etc/systemd/system/${EXS_CONTAINER_ID}.service\""
podman machine ssh systemctl enable "${EXS_CONTAINER_ID}.service"
podman machine ssh systemctl start "${EXS_CONTAINER_ID}.service"
fi
else
  echo "Failed to identify explainshell container"
  podman ps container -f name=explainshell
fi

podman machine stop || true
podman machine start

```

## Add ASDF's application manager

```zsh
## brew uninstall nodejs gtop python python-yq packer maven make jq jmespath jib temurin zoxide jenv
# gradle groovy maven awscli bat

asdf plugin add direnv
asdf global direnv latest
asdf install direnv latest

ASDF_PLUGIN_NAMES=(jbang jib yq zoxide vim git sqlite snyk shellcheck shfmt semver semgrep shellspec "python:3.10" rabbitmq:system bun nodejs packer maven direnv gradle groovy cheat awscli aws-vault awsebcli aria2 act bat "java:temurin-11" "java:temurin-18")


asdf global rabbitmq system

for pluginVersion in "${ASDF_PLUGIN_NAMES[@]}"; do
plugin=${pluginVersion%%:*}
version=${pluginVersion#*:}
version=${version:+latest:${version}}
[[ ${version##latest:} == "system" ]] || version="system"
[[ ${version##latest:} == "latest" ]] || version="latest"
  asdf plugin add "${plugin}"
  [[ ${version} != "system" ]] && $asdf install "${plugin}" ${version}
  asdf global "${plugin}" ${version}
done

```

### `~/.zshrc`

```zsh
#!/usr/bin/env zsh
export TERM='xterm-256color'

ANTIGEN_SOURCE_PATH=/usr/local/share/antigen/antigen.zsh

if [[ ! -f "${ANTIGEN_SOURCE_PATH}" ]]; then
  mkdir -p "$(dirname "${ANTIGEN_SOURCE_PATH}")"
  curl -L git.io/antigen >"${ANTIGEN_SOURCE_PATH}"
fi

run_after_wait() {
  local -r wait_in_seconds="$1"
  shift
  sleep "${wait_in_seconds}"s
  "$@"
}

generate_antigen_cache() {
  SECONDS_IN_DAY=86400
  SECONDS_IN_WEEK=$((SECONDS_IN_DAY * 7))

  mkdir -p ~/.cache/antigen
  run_timer="${HOME}/.cache/antigen/antigen.cachegen.last_run"

  if [[ ! -f "${run_timer}" ]]; then
    touch "${run_timer}"
    last_run_time="$(date +%s)"
  else
    last_run_time="$(stat -f "%m" "${run_timer}")"
  fi

  if [[ "$(date +%s)" -gt "$((last_run_time + SECONDS_IN_WEEK))" ]]; then
    touch "${run_timer}"
    setopt local_options no_notify no_monitor
    run_after_wait "$((130 + RANDOM % 100))" antigen cache-gen &
  fi
}

source "${ANTIGEN_SOURCE_PATH}"
antigen init ~/.antigenrc
# generate_antigen_cache
[[ -n ${ZSH_CACHE_DIR} ]] && [[ ! -d "${ZSH_CACHE_DIR}/completions" ]] && mkdir -p "${ZSH_CACHE_DIR}/completions"

# export PROMPT='$(gbt $?)'

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

add_to_path() {
  if [[ -d "${1}" ]]; then
    if [[ -z "${PATH}" ]]; then
      export PATH="${1}"
    elif grep -q -v "${1}" <<<"${PATH}"; then
      export PATH="${1}:${PATH}"
    fi
  fi
}

export FZF_BASE="$(brew --prefix fzf)"
if [[ ~/.vimrc ]]; then
  if grep -q -v 'set rtp+=/usr/local/opt/fzf' ~/.vimrc; then
    echo 'set rtp+=/usr/local/opt/fzf' >>~/.vimrc
  fi
else
  echo 'set rtp+=/usr/local/opt/fzf' >~/.vimrc
fi

[[ ! -f ~/.fzf.zsh ]] && [[ -f /usr/local/opt/fzf/install ]] && /usr/local/opt/fzf/install --completion --key-bindings --all >/dev/null 2>&1
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

[[ -f /usr/local/opt/asdf/libexec/asdf.sh ]] && \. /usr/local/opt/asdf/libexec/asdf.sh
eval $(thefuck --alias)

# You may need to manually set your language environment
export LANG=en_US.UTF-8
export GPG_TTY=${TTY}

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

alias pyauth='chamber exec dev-ws/us-east-1 GOOGLE_API_KEY -- pipenv run'
export AWS_SESSION_TOKEN_TTL=8h

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true

# export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters
[[ -f /usr/local/share/zsh/site-functions ]] && . /usr/local/share/zsh/site-functions
add_to_path "/usr/local/opt/ruby/bin"
add_to_path "$HOME/.yarn/bin"
add_to_path "$HOME/.config/yarn/global/node_modules/.bin"
add_to_path "/usr/local/opt/apr/bin"
add_to_path "${HOME}/.local/bin"
add_to_path "$HOME/.serverless/bin"
add_to_path "/usr/local/opt/gnu-tar/libexec/gnubin"
add_to_path "/usr/local/opt/gnu-sed/libexec/gnubin"
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source ~/wearsafe/github_login_tokens.sh

source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
. ~/.asdf/plugins/java/set-java-home.zsh

# bun completions
[ -s "/usr/local/share/zsh/site-functions/_bun" ] && source "/usr/local/share/zsh/site-functions/_bun"

# bun completions
[ -s "/Users/jamienelson/.bun/_bun" ] && source "/Users/jamienelson/.bun/_bun"

export DOCKER_HOST='unix:///Users/jamienelson/.local/share/containers/podman/machine/podman-machine-default/podman.sock'
alias docker=podman
export BFD_REPOSITORY="${HOME}/.shell-scripts"

```

## VS Code Setup

```sh
# Install VS Code
brew install --cask visual-studio-code
command -v code >/dev/null 2>&1 || { echo >&2 "VS Code is not installed.  Aborting."; exit 1; }
docker container run --name explainshell --restart always -p 5437:5000 -d spaceinvaderone/explainshell
```

# Install VS Code extensions

## Suggested Extra Tools:

-   [asdf](<>)
-   [gtop](<>)
-   [topgrade](<>)
-   [bat](<>)
-   [fd](<>)
-   [procs](<>)
-   [dust](<>)
-   [tldr](<>) **npm install -g tldr**
-   [broot](<>) **brew install broot**
-   [gping](https://github.com/orf/gping)
-   [glances](https://github.com/nicolargo/glances) **brew install glances**
-   [hyperfine](https://github.com/sharkdp/hyperfine) **brew install hyperfine**

## [Hyperfine](https://github.com/sharkdp/hyperfine)

### Shell functions and aliases

#### If you are using bash, you can export shell functions to directly benchmark them with hyperfine:

```sh
$ my_function() { sleep 1; }
$ export -f my_function
$ hyperfine my_function
```

```

```
