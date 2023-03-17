#!/usr/bin/env bash
# shellcheck disable=SC2034

## This can be run in bash or zsh and provide the same results

print_function_name() {
  local level="${1:-0}"
  if [[ -n ${FUNCNAME[${level}]}   ]]; then
    printf '%s\n' "${FUNCNAME[${level}]}"
  else
    printf '%s\n' "${funcstack[@]:level:1}"
  fi
}

print_parent_of_current_func_name() {
  print_function_name 3
}
print_current_func_name() {
  print_function_name 2
}

parent_func() {
  printf 'current function name: '
  print_current_func_name
  printf 'parent of parent_func() function name: '
  print_parent_of_current_func_name
}

run_naming_functions() {
  printf 'current function name: '
  print_current_func_name
  printf 'Call parent_func(): \n'
  parent_func
}
printf 'Call run_naming_functions(): \n'
run_naming_functions
