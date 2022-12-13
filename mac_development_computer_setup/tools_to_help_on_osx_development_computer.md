# Tools and Shell Improvements for MacOS Development Computer

## Required Package Managers for MacOS

Where possible packages are installed to userspace, but some packages require root access.
If you see an opportunity to switch any of the root access installations to userspace, please [submit a PR](https://github.com/bitflight-devops/shell-scripts/pulls),or a [new issue](https://github.com/bitflight-devops/shell-scripts/issues/new/choose).

- [Homebrew](https://brew.sh/) is the most ubiquitous package manager for MacOS. It is required for installing many of the tools listed below.
- [Docker for Mac](https://docs.docker.com/desktop/install/mac-install/) is the most integrated container manager for MacOS, and is required for running many of the tools listed below.
- [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html) is the package manager for Rust, and is required for installing some of the high performance tools listed below.
- [pipx](https://pipxproject.github.io/pipx/) is the package manager for Python, and is required for installing some of the python tools listed below, into _userspace_.

### Install [Homebrew](https://brew.sh/)

Install Homebrew without being prompted for input.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
NONINTERACTIVE=1 sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Fix permissions for Homebrew
sudo zsh -c "$(declare -f compaudit);compaudit | xargs chown -R \"$(whoami)\""
# Fix permissions on all files in /usr/local
sudo zsh -c "$(declare -f compaudit);compaudit | xargs chmod go-w"
```

</details>

### Install [Docker for Mac](https://docs.docker.com/desktop/install/mac-install/)

<details><summary>Mac Intel Chip Requirements</summary>
* macOS must be version 10.15 or newer. That is, Catalina, Big Sur, or Monterey. We recommend upgrading to the latest version of macOS.
* At least 4 GB of RAM.
* VirtualBox prior to version 4.3.30 must not be installed as it is not compatible with Docker Desktop.

</details>
<details><summary>Mac M1 Chip Requirements</summary>

- Beginning with Docker Desktop 4.3.0, we have removed the hard requirement to install Rosetta 2. There are a few optional command line tools that still require Rosetta 2 when using Darwin/AMD64. See the Known issues section. However, to get the best experience, we recommend that you install Rosetta 2. To install Rosetta 2 manually from the command line, run the following command:

  ```zsh
    softwareupdate --install-rosetta
  ```

</details>

<details><summary>🗒️ Setup Instructions</summary>

- Manual install via a package installer are [available via the docker website](https://docs.docker.com/desktop/install/mac-install/).

- Scripted install via [install_docker_for_mac.sh](install_docker_for_mac.sh) script in your terminal:

  ```zsh
  # It requires root access, so you will be prompted for your password if you are not already root
  sudo -v # Prompt for sudo first
  curl -sL "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/mac_development_computer_setup/install_docker_for_mac.sh" | bash
  ```

</details>

## Install [Rustup](https://rust-lang.github.io/rustup/installation/other.html)/[Cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html)

Instructions to download and install the official compiler for the Rust
programming language, and its package manager, <a href="https://doc.rust-lang.org/cargo/getting-started/installation.html">Cargo</a>.

<details><summary>🗒️ Setup Instructions</summary>

[Rustup](https://rust-lang.github.io/rustup/installation/other.html) metadata and toolchains will be installed into the Rustup home directory, located at:

```zsh
  ~/.rustup
```

This can be modified with the `RUSTUP_HOME` environment variable.

The Cargo home directory is located at:

```zsh
  ~/.cargo
```

This can be modified with the `CARGO_HOME` environment variable.

The `cargo`, `rustc`, `rustup` and other commands will be added to
Cargo's bin directory, located at:

```zsh
  ~/.cargo/bin
```

This path will then be added to your `PATH` environment variable by
modifying the profile files located at:

```zsh
  /Users/jamienelson/.profile
  /Users/jamienelson/.bash_profile
  /Users/jamienelson/.bashrc
  /Users/jamienelson/.zshenv
```

You can uninstall at any time with `rustup self uninstall` and
these changes will be reverted.

```zsh
# Remove any existing rust installations in brew
brew list rust >/dev/null 2>&1 && brew uninstall rust
# TODO add `asdf` check and uninstall

# Install rustup:
# Options: -y = non-interactive, -q = quiet, -v = verbose
#          --default-host <default-host>              Choose a default host triple
#          --default-toolchain <default-toolchain>    Choose a default toolchain to install
#          --default-toolchain none                   Do not install any toolchains
#          --profile [minimal|default|complete]       Choose a profile
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain nightly
```

</details>

### Install Python and [pipx](https://pipxproject.github.io/pipx/)

The latest version of python is installed via Homebrew, and pipx is installed via pip.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
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
```

</details>

### Install [meta-package-manager](https://kdeldycke.github.io/meta-package-manager/install.html) (mpm)

```sh
pipx install meta-package-manager || true
```

## Installation Helper Functions

**NOTE:** _These shell functions are required for the rest of the setup_
Add [these helper functions](mac_development_computer_setup/helper_functions.sh) to your shell profile.
They are required for the rest of the installation process.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
helper_script="${HOME}/.local/shell-scripts/lib/mac_development_computer_setup/helper_functions.sh"
mkdir -p "$(dirname "${helper_script}")" || return 1
curl -SfslL -o "${helper_script}" "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/mac_development_computer_setup/helper_functions.sh"

if [[ -f "${helper_script}" ]]; then
  source "${helper_script}"
  # Adds them if they are not there, otherwise does nothing
  add_helper_functions_to_profile
fi
```

</details>

## Configure Package Repositories

### Setup Brew Taps

custom software repositories

**NOTE:** This requires the [helper functions from this step](#installation-helper-functions) to be available.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
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

</details>

## Install Runtimes

### Install Java Runtimes

Java has been depreciated from oracle, and is now only available from 3rd party providers.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
### The adoptopenjdk/openjdk tap is deprecated use homebrew/cask-versions instead
brew untap adoptopenjdk/openjdk || true

brew_install_all --cask temurin temurin8 temurin11 temurin18 # Java JDK's
```

</details>

## ZSH Plugin Frameworks

### [zr](https://github.com/jedahan/zr)

Quick, simple zsh plugin manager

Configuration of this plugin manager is done later in this document.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
cargo install zr
```

</details>

## Collect and Install Mac Development Support Tools

### Cargo Packages

```zsh
cargo_packages=()
cargo_packages+=("cargo-edit") # Cargo subcommand for managing dependencies
cargo_packages+=("cargo-make") # Make-like build tool for Rust
cargo_packages+=("cargo-watch") # Watch Cargo.toml and Cargo.lock for changes and rerun cargo build
cargo_packages+=("coreutils") # GNU core utilities
cargo_packages+=("shellharden") # Shellharden is a tool to make shell scripts more robust

cargo install "${cargo_packages[@]}"
: # Post Install
~/.cargo/bin/coreutils
```

### Brew Packages and Casks

<details><summary>🗒️ Setup Instructions</summary>

```zsh
brew_apps=()
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
brew_apps+=("uutils-coreutils") # GNU File, Shell, and Text utilities written in rust
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
brew_apps+=("sk") # Fuzzy finder in rust!
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

brew_install_all "${brew_apps[@]}"
```

</details>

### brew bundle install

TODO: Add section here with details about how to install the brew bundle

### Install Other Utilities (Not in Homebrew)

```zsh
pipx install emoji-fzf
npm install -g tldr # Manuals and HowTo's
curl -fsSL https://git.io/shellspec | sh -s -- --yes # Shell Check for running tests against shell scripts
```

## Add ASDF's application manager

ASDF is a tool that allows you to manage multiple language runtime versions on your local system. It is similar to tools like `nvm` and `rbenv` in that it allows you to have multiple versions of a language runtime installed on your system and switch between them.

<details><summary>🗒️ Setup Instructions</summary>

```zsh
## brew uninstall nodejs gtop python python-yq packer maven make jq jmespath jib temurin zoxide jenv
# gradle groovy maven awscli bat
brew install asdf
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

</details>

## Configure ZSH

Via `~/.zshrc`

<details><summary>🗒️ Setup Instructions</summary>

```zsh
#!/usr/bin/env zsh
# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='code'
fi

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

mkdir -p ~/.local/bin
# Generate new ~/.config/zr.zsh if it does not exist or if ~/.zshrc has been changed
if [[ ! -f ~/.config/zr.zsh ]] || [[ ~/.zshrc -nt ~/.config/zr.zsh ]]; then
  zr \
    https://github.com/bitflight-devops/shell-scripts \
    > ~/.config/zr.zsh
fi

source ~/.config/zr.zsh

# Enable Touchbar support for iTerm2
TOUCHBAR_GIT_ENABLED=true

install_if_missing starship starship "https://starship.rs/install.sh" "-f" "-b" "$HOME/.local/bin"
install_if_missing fig fig "https://fig.io/install"

[[ -f /usr/local/opt/asdf/libexec/asdf.sh ]] && source /usr/local/opt/asdf/libexec/asdf.sh
[[ -f ~/wearsafe/github_login_tokens.sh ]] && source ~/wearsafe/github_login_tokens.sh
[[ -f ~/.asdf/plugins/java/set-java-home.zsh ]] && source ~/.asdf/plugins/java/set-java-home.zsh
[[ -n ${ZSH_CACHE_DIR} ]] && [[ ! -d "${ZSH_CACHE_DIR}/completions" ]] && mkdir -p "${ZSH_CACHE_DIR}/completions"

run_after_wait() {
  local -r wait_in_seconds="$1"
  shift
  sleep "${wait_in_seconds}"s
  "$@"
}

# bun completions
[ -s "/usr/local/share/zsh/site-functions/_bun" ] && source "/usr/local/share/zsh/site-functions/_bun"

# bun completions
[ -s "/Users/jamienelson/.bun/_bun" ] && source "/Users/jamienelson/.bun/_bun"

export ZSH_WAKATIME_PROJECT_DETECTION=true

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

# Start Starship prompt is available
if command_exists starship; then
  eval "$(starship init zsh)"
else
  NONINTERACTIVE=1 curl -sS https://starship.rs/install.sh | sh
fi
# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"

```

</details>

## VS Code Setup

Install and setup VS Code

<details><summary>🗒️ Setup Instructions</summary>

```sh
# Install VS Code
brew install --cask visual-studio-code
```

</details>

### Install VS Code extensions

TODO: Add instructions for installing VS Code extensions

## Benchmarking Shell functions and aliases

### If you are using bash, you can export shell functions to directly benchmark them with hyperfine

```zsh
     my_function() { sleep 1; }
     export -f my_function
     hyperfine my_function
```
