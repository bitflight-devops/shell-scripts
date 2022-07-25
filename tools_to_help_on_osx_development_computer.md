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

### Install [Zi](https://wiki.zshell.dev/docs/intro)

```sh
sh -c "$(curl -fsSL https://git.io/get-zi)" -- -i skip  -a loader -b main
```

### Install utilities:

````zsh
# Connect to Third Party Brew Repos
brew tap aws/tap
brew tap lucagrulla/tap
brew tap mutagen-io/mutagen 
brew tap sass/sass
brew tap hashicorp/tap
brew tap codacy/tap

# Install Runtimes
brew install cask
brew uninstall python2 2>/dev/null || true
brew install python@3.10 python-tk@3.10
python -m ensurepip --upgrade
python-pip python-yq 
brew install node groovy ruby rust golang
brew install --cask temurin

# Install General and System Utilities
brew install --cask rectangle  graphiql # GUI utilities
brew install --cask iterm2 font-hack-nerd-font # Terminal Gui

# ZSH Terminal Enhancements
brew install \
  antigen \
  asciinema \
  autoconf \
  automake \
  brotli \
  ca-certificates \
  cask \
  confd \
  coreutils \
  curl \
  dust \
  emacs \
  fontconfig \
  fzf \
  gcc \
  gd \
  gdbm \
  gh \
  git \
  glances \
  glib \
  gnu-sed \
  gnupg \
  gnupg2 \
  gnutils \
  google-java-format \
  graphite2 \
  guile \
  htop \
  hyperfine \
  jasper \
  jpeg \
  jpeg-turbo \
  jq \
  libiconv \
  libpng \
  libssh2 \
  libtiff \
  libwebp \
  libxml2 \
  libxml2-dev \
  libxslt \
  libxslt-dev \
  libyaml \
  links \
  lua \
  lz4 \
  m4 \
  mas \
  ncurses \
  netcat \
  nettle \
  nghttp2 \
  perl \
  perltidy \
  pipx \
  pkg-config \
  procs \
  pylint \
  python-yq \
  rbenv \
  readline \
  remake \
  ruby-build \
  sass \
  shellcheck \
  shfmt \
  telnet \
  tmux \
  topgrade \
  tree \
  unzip \
  vim \
  wget \
  xmlstarlet \
  gnu-tar

# Install Development Tools + Docker Tools
brew install mutagen mutagen-compose hadolint # Docker Helpers
brew install act actionlint gh hub # GitHub CLI Tools
brew install podman # Alternitive To Docker

# Install Java Utilities
brew install maven gradle groovy jenv

# Install Cloud Utilities
brew install --cask aws-vault

brew install \
  awscli \
  aws-vault \
  hashicorp/tap/packer \
  tfenv \
  chamber \
  docker-credential-helper-ecr \
  aws-sam-cli \
  awsebcli \
  aws-elasticbeanstalk \
  packer

brew tap homebrew/cask-fonts
brew install --cask font-dejavu-sans-mono-nerd-font

brew cleanup

# Install Other Utilities (Not in Homebrew)
npm install -g tldr # Manuals and HowTo's
curl -fsSL https://git.io/shellspec | sh -s -- --yes # Shell Check for running tests against shell scripts

python -m ensurepip --upgrade
python -m pip install --upgrade pip  2>&1 |  grep -v "DEPRECATION:"
python -m pip install --upgrade pipx 2>&1 |  grep -v "DEPRECATION:"

# Initialise Utilities
podman machine init
podman machine set --rootful # Optionally Enable root permissions to allow access to low port numbers 0-1024
sudo "$(brew --prefix podman)/bin/podman-mac-helper" install # Install podman-mac-helper

podman machine stop || true
podman machine start

# Add ASDF's application manager
#brew uninstall nodejs gtop python python-yq packer maven make jq jmespath jib temurin zoxide jenv
# gradle groovy maven awscli bat
asdf plugin add direnv
asdf global direnv latest
asdf install direnv latest
brew install gpg gawk rabbitmq
brew link --overwrite gnupg
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
ANTIGEN_SOURCE_PATH=/usr/local/share/antigen/antigen.zsh
if [[ ! -f "${ANTIGEN_SOURCE_PATH}" ]]; then
  mkdir -p "$(dirname "${ANTIGEN_SOURCE_PATH}")"
  curl -L git.io/antigen >"${ANTIGEN_SOURCE_PATH}"
fi

source "${ANTIGEN_SOURCE_PATH}"
antigen use oh-my-zsh
antigen bundle git
antigen bundle asdf
# antigen bundle curl
antigen bundle fzf
antigen bundle aws
antigen bundle brew
antigen bundle docker
antigen bundle gh
antigen bundle iterm2
antigen bundle macos
antigen bundle npm
antigen bundle nvm
antigen bundle thefuck
antigen bundle tmux
antigen bundle vscode
antigen bundle yarn
antigen bundle zoxide
antigen bundle Aloxaf/fzf-tab
antigen bundle zdharma-continuum/fast-syntax-highlighting
antigen bundle \
  zsh-users/zsh-autosuggestions \
  zsh-users/zsh-completions \
  zsh-users/zsh-history-substring-search

antigen theme romkatv/powerlevel10k

antigen apply

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
add_to_path "/usr/local/opt/gnu-sed/libexec/gnubin"
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi
fpath=(~/.zsh $fpath)
autoload -Uz compinit
compinit -u

source <(curl -sL https://git.io/zi-loader) 2>/dev/null || true
zzinit 2>/dev/null || true

if command_exists zi; then
  zi light z-shell/zui
  zi light z-shell/zsh-lint
fi

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

[[ -f ~/perl5/perlbrew/etc/bashrc ]] && \. ~/perl5/perlbrew/etc/bashrc
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

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.zsh
# tabtab source for slss package
# uninstall by removing these lines or running `tabtab uninstall slss`
[[ -f /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/slss.zsh ]] && . /usr/local/lib/node_modules/serverless/node_modules/tabtab/.completions/slss.zsh

add_to_path "/usr/local/opt/openssl@1.1/bin"
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
add_to_path "$HOME/.jenv/bin"
add_to_path "$HOME/.serverless/bin"
add_to_path "/usr/local/opt/python/libexec/bin"

eval "$(jenv init -)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source ~/wearsafe/github_login_tokens.sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jamienelson/google-cloud-sdk/path.zsh.inc' ]; then \. '/Users/jamienelson/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jamienelson/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jamienelson/google-cloud-sdk/completion.zsh.inc'; fi

[[ -f ~/perl5/perlbrew/etc/bashrc ]] && . ~/perl5/perlbrew/etc/bashrc

```

## VS Code Setup

```sh
# Install VS Code
brew install --cask visual-studio-code
command -v code >/dev/null 2>&1 || { echo >&2 "VS Code is not installed.  Aborting."; exit 1; }
docker container run --name explainshell --restart always -p 5437:5000 -d spaceinvaderone/explainshell
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
