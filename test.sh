#!/usr/bin/env bash
if ! command -v info_log > /dev/null 2>&1; then
  info_log() {
    echo "INFO: $*"
  }
fi

if [[ ${GITHUB_ACTIONS+x} == x ]]; then
  info_log "Running tests in GitHub Actions"
  . tests/run.sh "$@"
else
  info_log "Running tests locally in docker-compose"
  docker compose run -it test "$@"
fi
