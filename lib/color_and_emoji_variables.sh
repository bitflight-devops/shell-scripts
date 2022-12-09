#!/usr/bin/env bash
# No Side Effects
command_exists() { command -v "$@" > /dev/null 2>&1; }
: "${COLOR_AND_EMOJI_VARIABLES_LOADED:=1}"
this_tput="$(command_exists tput && echo 'tput' || printf '')"
BOLD="$(this_tput bold 2> /dev/null || printf '')"
GREY="$(this_tput setaf 0 2> /dev/null || printf '')"
UNDERLINE="$(this_tput smul 2> /dev/null || printf '')"
RED="$(this_tput setaf 1 2> /dev/null || printf '')"
GREEN="$(this_tput setaf 2 2> /dev/null || printf '')"
YELLOW="$(this_tput setaf 3 2> /dev/null || printf '')"
BLUE="$(this_tput setaf 4 2> /dev/null || printf '')"
MAGENTA="$(this_tput setaf 5 2> /dev/null || printf '')"
NO_COLOR="$(this_tput sgr0 2> /dev/null || printf '')"

# string formatters
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

# if test -t 1 && command_exists tput && [[ $(this_tput colors 2> /dev/null || printf '0') -gt 0 ]]; then
  COLOR_BRIGHT_BLACK=$'\e[0;90m'
  COLOR_BRIGHT_RED=$'\e[0;91m'
  COLOR_BRIGHT_GREEN=$'\e[0;92m'
  COLOR_BRIGHT_YELLOW=$'\e[0;93m'
  COLOR_BRIGHT_BLUE=$'\e[0;94m'
  COLOR_BRIGHT_MAGENTA=$'\e[0;95m'
  COLOR_BRIGHT_CYAN=$'\e[0;96m'
  COLOR_BRIGHT_WHITE=$'\e[0;97m'
  COLOR_GREY=$'\x1b\x5b\x33\x30\x6d'
  COLOR_BLACK=$'\e[0;30m'
  COLOR_RED=$'\e[0;31m'
  COLOR_GREEN=$'\e[0;32m'
  COLOR_YELLOW=$'\e[0;33m'
  COLOR_BLUE=$'\e[0;34m'
  COLOR_MAGENTA=$'\e[0;35m'
  COLOR_CYAN=$'\e[0;36m'
  COLOR_WHITE=$'\e[0;37m'
  COLOR_BOLD_BLACK=$'\e[1;30m'
  COLOR_BOLD_RED=$'\e[1;31m'
  COLOR_BOLD_GREEN=$'\e[1;32m'
  COLOR_BOLD_YELLOW=$'\e[1;33m'
  COLOR_BOLD_BLUE=$'\e[1;34m'
  COLOR_BOLD_MAGENTA=$'\e[1;35m'
  COLOR_BOLD_CYAN=$'\e[1;36m'
  COLOR_BOLD_WHITE=$'\e[1;37m'
  COLOR_BOLD=$'\e[1m'
  COLOR_BOLD_YELLOW=$'\e[1;33m'
  COLOR_BG_BLACK=$'\e[1;40m'
  COLOR_BG_RED=$'\e[1;41m'
  COLOR_BG_GREEN=$'\e[1;42m'
  COLOR_BG_YELLOW=$'\e[1;43m'
  COLOR_BG_BLUE=$'\e[1;44m'
  COLOR_BG_MAGENTA=$'\e[1;45m'
  COLOR_BG_CYAN=$'\e[1;46m'
  COLOR_BG_WHITE=$'\e[1;47m'
  COLOR_RESET=$'\e[0m'
  CLEAR_SCREEN="$(this_tput rc 2> /dev/null || printf '')"
# fi

#BASIC_ICONS
INFORMATION_ICON=$'\342\204\271'      # ℹ Information
GEAR_ICON=$'\342\232\231'             # ⚙ Gear
TOOLS_ICON=$'\342\232\222'            # ⚒ Tools
ITALIC_CROSS_ICON=$'\342\234\227'     # ✗ Italic Cross
SKULL_ICON=$'\xE2\x98\xA0'            # ☠ Skull and Crossbones
HAZARD_ICON=$'\342\232\240'           # ⚠ Hazard
BALLOT_TICK_ICON=$'\342\230\221'      # ☑ Ballot Box With Tick
BALLOT_CROSS_ICON=$'\342\230\222'     # ☒ Ballot Box With X
ELIPSIS_ICON=$'\342\200\246'          # … Elipsis
UMBRELLA_ICON=$'\342\230\202'         # ☂ Umbrella
CIRCLE_BULLET_ICON=$'\342\232\254'    # ⚬ Circle Bullet
HIDDEN_CIRCLE_ICON=$'\342\227\214'    # ◌ Hidden Circle
VISIBLE_CIRCLE_ICON=$'\342\227\213 '  # ○ Visible Circle
TRIANGLE_ICON=$'\342\226\276'         # ▾ Triangle
CROSS_ICON=$'\342\230\223'            # ☓ Cross
BOLD_CROSS_ICON=$'\342\234\226'       # ✖ Bold Cross
CHECK_ICON=$'\342\234\223'            # ✓ Check
SWORDS_ICON=$'\342\232\224'           # ⚔ Swords
SWERVE_ICON=$'\342\230\241'           # ☡ Swerve
STAR_OPEN_ICON=$'\342\230\206'        # ☆ Star Open
STAR_FILLED_ICON=$'\342\230\205'      # ★ Star Filled
LIGHTNING_ICON=$'\342\232\241'        # ⚡ Lightning
FLAG_ICON=$'\342\232\221'             # ⚑ Flag
HAND_PEN_ICON=$'\342\234\215'         # ✍ Hand Pen
PENCIL_ICON=$'\342\234\217'           # ✏ Pencil

# Mapped Icon Labels
SUCCESS_ICON=${SUCCESS_ICON:-${CHECK_ICON}}
FAILURE_ICON=${FAILURE_ICON:-${CROSS_ICON}}
FATAL_ICON=${FATAL_ICON:-${SKULL_ICON}}
WARNING_ICON=${WARNING_ICON:-${HAZARD_ICON}}
ERROR_ICON=${ERROR_ICON:-${ITALIC_CROSS_ICON}}
DEBUG_ICON=${DEBUG_ICON:-${GEAR_ICON}}
INFO_ICON=${INFO_ICON:-${INFORMATION_ICON}}
START_ICON=${START_ICON:-${STAR_FILLED_ICON}}
OPTION_ICON=${OPTION_ICON:-${VISIBLE_CIRCLE_ICON}}
STEP_ICON=${STEP_ICON:-${STAR_OPEN_ICON}}
PASS_ICON=${PASS_ICON:-${BALLOT_TICK_ICON}}
FAIL_ICON=${FAIL_ICON:-${BALLOT_CROSS_ICON}}
SKIP_ICON=${SKIP_ICON:-${HIDDEN_CIRCLE_ICON}}
IN_PROGRESS_ICON=${IN_PROGRESS_ICON:-${CIRCLE_BULLET_ICON}}
DONE_ICON=${DONE_ICON:-${FLAG_ICON}}
MAINTENANCE_ICON=${MAINTENANCE_ICON:-${TOOLS_ICON}}
PROBLEM_ICON=${PROBLEM_ICON:-${UMBRELLA_ICON}}
NOTICE_ICON=${NOTICE_ICON:-${LIGHTNING_ICON}}
RESULTS_ICON=${RESULTS_ICON:-${PENCIL_ICON}}
