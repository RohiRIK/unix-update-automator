#!/usr/bin/env bats

load 'test_helper'

@test "shows help message" {
  run ./unix_update_automator.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
