# Shell Script Utilities

<!-- start title -->


<!-- end title -->

<!-- start description -->


<!-- end description -->



## CLI Install

Install Options as Environment Vars:
* `INTERACTIVE=1` force interactive mode (default when running in a terminal)
* `NONINTERACTIVE=1` force non-interactive mode (default when in CI environment)

*Make sure that you have downloader like curl:*
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

## Action Usage


<!-- start usage -->


<!-- end usage -->

## GitHub Action Inputs

<!-- start inputs -->


<!-- end inputs -->

## GitHub Action Outputs

<!-- start outputs -->


<!-- end outputs -->
