#!/bin/bash

set -eu

usage_exit() {
  prog="./$(basename $0)"
  echo_err "usage: $prog [OPTIONS...] ARGS..."
  echo_err ""
  echo_err "options:"
  echo_err " --dry-run           : Don't make any change (default)"
  echo_err " -f, --force         : Force mode"
  echo_err " -l ITEM --list ITEM : Set list items"
  echo_err " -V VAL --value VAL  : Set value"
  echo_err " -v, --verbose       : Verbose mode"
  exit 1
}

echo_err() {
  echo "$1" 1>&2
}

option_dry_run=yes
option_list=()
option_value=''
option_verbose=0

while getopts -- "-:fhl:V:v" OPT; do
  case $OPT in
    -)
      case $OPTARG in
        dry-run)
          option_dry_run=yes
          ;;
        force)
          option_dry_run=no
          ;;
        list)
          LONGOPT_ARG="${BASH_ARGV[$(($BASH_ARGC-$OPTIND))]}"
          option_list+=($LONGOPT_ARG)
          OPTIND=$((OPTIND+1))
          ;;
        value)
          LONGOPT_ARG="${BASH_ARGV[$(($BASH_ARGC-$OPTIND))]}"
          option_value+=($LONGOPT_ARG)
          OPTIND=$((OPTIND+1))
          ;;
        verbose)
          option_verbose=$(($option_verbose+1))
          ;;
        *)
          echo_err "$0: illegal option -- $OPTARG"
          usage_exit
          ;;
      esac;;
    f) option_dry_run=no;;
    h) usage_exit;;
    l) option_list+=($OPTARG);;
    V) option_value=$OPTARG;;
    v) option_verbose=$(($option_verbose+1));;
    \?) usage_exit;;
  esac
done
shift $((OPTIND-1))

cat <<__JSON__
{
  "option_dry_run": "$option_dry_run",
  "option_value": "$option_value",
  "option_verbose": $option_verbose,
  "option_list": [$(
    if [[ ${#option_list[@]} -ne 0 ]]; then
      for e in ${option_list[@]}; do
        echo "\"$e\""
      done | paste -sd,
    fi
  )],
  "arguments": [$(
    i=0
    while [[ $# -gt 0 ]]; do
      echo "\"$1\""
      shift
    done | paste -sd,
  )]
}
__JSON__
