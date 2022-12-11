#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")"  > /dev/null 2>&1 && pwd)"
git submodule update --init --recursive
find "${DIR}" -name '*-bash-test.sh' -exec bash {} \;
