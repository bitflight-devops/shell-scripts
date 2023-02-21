# Shell Script Utilities

<!-- start title -->

<!-- end title -->

<!-- start description -->

<!-- end description -->

## Use in Github actions

```yml
- uses: bitflight-devops/shell-scripts@v2
  name: Install shell utility scripts
```

## CLI Install

Install Options as Environment Vars:

- `INTERACTIVE=1` force interactive mode (default when running in a terminal)
- `NONINTERACTIVE=1` force non-interactive mode (default when in CI environment)

_Make sure that you have downloader like curl:_
Debian & Ubuntu: `apt-get update -y -qq && apt-get install -y -qq curl`
Yum & CentOS: `yum install -y -q curl`

### Install without prompts

```bash
sudo -v 2>/dev/null || true # Prompt for sudo first
NONINTERACTIVE=1 source <(curl -sL "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/install.sh")
source "$BFD_REPOSITORY/lib/bootstrap.sh" || true
```

## CLI Usage

Load the functions:

```bash
# SILENT_BOOTSTRAP=1 # disable info logs if uncommented
. lib/bootstrap.sh
```

Add this to the top of scripts that need to use the functions:

```bash
#!/usr/bin/env bash
if [[ -z ${BFD_REPOSITORY:-} ]]; then
  if [[ -x "/home/bitflight-devops/.shell-scripts" ]]; then
    export BFD_REPOSITORY="/home/bitflight-devops/.shell-scripts"
  elif [[ -x "${HOME}/.shell-scripts" ]]; then
    export BFD_REPOSITORY="${HOME}/.shell-scripts"
  elif [[ -x "/usr/local/.shell-scripts" ]]; then
    export BFD_REPOSITORY="usr/local/.shell-scripts"
  elif [[ -x "/opt/bitflight-devops/.shell-scripts" ]]; then
    export BFD_REPOSITORY="/opt/bitflight-devops/.shell-scripts"
  fi
fi

if [[ -n ${BFD_REPOSITORY:-} ]]; then
  source "${BFD_REPOSITORY}/lib/bootstrap.sh" || true
elif [[ -n "${SCRIPTS_LIB_DIR}" ]]; then
  source "${SCRIPTS_LIB_DIR}/bootstrap.sh" || true
else
  if command -v curl >/dev/null 2>&1; then
    NONINTERACTIVE=1 source <(curl -sL "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/install.sh") || true
  elif command -v wget >/dev/null 2>&1; then
    NONINTERACTIVE=1 source <(wget -q "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/install.sh") || true
  fi
  if [[ -x "${SCRIPTS_LIB_DIR}/bootstrap.sh" ]]; then
    source "${SCRIPTS_LIB_DIR}/bootstrap.sh" || true
  else
    echo "Failed to run bootstrap.sh"
    echo "Please install the shell-scripts repository from github.com/bitflight-devops/shell-scripts"
  fi
fi

## Continue the script

```

## Action Usage

<!-- start usage -->

<!-- end usage -->

## GitHub Action Inputs

<!-- start inputs -->

<!-- end inputs -->

## GitHub Action Outputs

<!-- start outputs -->

<!-- end outputs -->

## Testing

This project uses [shUnit2](https://github.com/kward/shunit2) for testing.
It is included as a submodule in the `tests` directory.
To run the tests, run `./tests/run.sh` from the root of the repository.
