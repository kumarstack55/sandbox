#!/usr/bin/env bats

@test "usage" {
  run ./script.sh -h
  [[ $output =~ 'usage' ]]
  [[ $status -ne 0 ]]
}

@test "default value" {
  run ./script.sh
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_dry_run==\"yes\"") == true ]]
}

@test "set dry run" {
  run ./script.sh --dry-run
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_dry_run==\"yes\"") == true ]]
}

@test "set force" {
  run ./script.sh -f
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_dry_run==\"no\"") == true ]]
}

@test "set long force option" {
  run ./script.sh --force
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_dry_run==\"no\"") == true ]]
}

@test "set multiple list options" {
  run ./script.sh -l item0 -l item1
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_list[0]==\"item0\"") == true ]]
  [[ $(echo $output | jq ".option_list[1]==\"item1\"") == true ]]
}

@test "set multiple long list options" {
  run ./script.sh --list item0 --list item1
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_list[0]==\"item0\"") == true ]]
  [[ $(echo $output | jq ".option_list[1]==\"item1\"") == true ]]
}

@test "set value" {
  run ./script.sh -V xx
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_value==\"xx\"") == true ]]
}

@test "override value" {
  run ./script.sh -V xx -V yy
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_value==\"yy\"") == true ]]
}

@test "set multiple verbose options" {
  run ./script.sh -vv
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_verbose==2") == true ]]
}

@test "set multiple long verbose options" {
  run ./script.sh --verbose --verbose
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_verbose==2") == true ]]
}

@test "set multiple arguments" {
  run ./script.sh arg0 arg1
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".arguments[0]==\"arg0\"") == true ]]
  [[ $(echo $output | jq ".arguments[1]==\"arg1\"") == true ]]
}

@test "options ignored after --" {
  run ./script.sh -v -- -v
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_verbose==1") == true ]]
  [[ $(echo $output | jq ".arguments[0]==\"-v\"") == true ]]
}

@test "options ignored after first argument" {
  run ./script.sh -f arg0 -v arg2
  [[ $status -eq 0 ]]
  [[ $(echo $output | jq ".option_dry_run==\"no\"") == true ]]
  [[ $(echo $output | jq ".arguments[0]==\"arg0\"") == true ]]
  [[ $(echo $output | jq ".arguments[1]==\"-v\"") == true ]]
  [[ $(echo $output | jq ".arguments[2]==\"arg2\"") == true ]]
  [[ $(echo $output | jq ".option_verbose==0") == true ]]
}

@test "illegal option" {
  run ./script.sh -x
  [[ $output =~ 'usage' ]]
  [[ $status -ne 0 ]]
}

@test "illegal long option" {
  run ./script.sh --wrong
  [[ $output =~ 'usage' ]]
  [[ $status -ne 0 ]]
}

@test "need args" {
  run ./script.sh -V
  [[ $output =~ 'usage' ]]
  [[ $status -ne 0 ]]
}

@test "need args long option" {
  run ./script.sh --value
  [[ $output =~ 'usage' ]]
  [[ $status -ne 0 ]]
}
