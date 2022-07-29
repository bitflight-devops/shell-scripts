# Shell Script Utilities

<!-- start title -->


<!-- end title -->

<!-- start description -->


<!-- end description -->



## CLI Install

Install Options as Environment Vars:
* `INTERACTIVE=1` force interactive mode (default when running in a terminal)
* `NONINTERACTIVE=1` force non-interactive mode (default when in CI environment)

```bash
# Make sure that you have downloader like curl:
# apt-get update -y -qq && apt-get install -y -qq curl
source <(curl -sL "https://raw.githubusercontent.com/bitflight-devops/shell-scripts/main/install.sh")
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
