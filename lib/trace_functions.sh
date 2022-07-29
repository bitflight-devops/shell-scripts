#!/usr/bin/env bash
export TRACE_FUNCTIONS_LOADED=1
xtrace() {
  # Print the line as if xtrace was turned on, using sed to filter out
  # the extra colon character and the following "set +x" line.
  (
    set -x
    # Colon is a no-op in bash, so nothing will execute.
    "$@"
    set +x
  ) 2>&1 | sed -e 's/^[+]:/+/g' -e '/^[+]*set +x$/d' 1>&2
  # Execute the original line unmolested
  # "$@"
}
