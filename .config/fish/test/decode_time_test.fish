#!/usr/local/bin/fish

function test_decode_time
  set -l number $argv[1]
  set -l expected $argv[2]
  set -l millis $argv[3]
  set -l actual

  if test "$millis" = "m"
    set actual (decode_time -m "$number")
  else
    set actual (decode_time "$number")
  end

  if test "$expected" = "$actual"
    set_color green
    echo -n .
  else
    set_color red
    echo FAIL "'$number'->'$expected' : Got: $actual"
  end

  set_color normal
end

test_decode_time 1 '1s'
test_decode_time 2 '2s'
test_decode_time 60 '1m 0s'
test_decode_time 61 '1m 1s'

test_decode_time 61 '0s 61ms' m
test_decode_time 1001 '1s 1ms' m

test_decode_time 3600 '1h 0m 0s'
test_decode_time 3661 '1h 1m 1s'
test_decode_time 86400 '1d 0h 0m 0s'
test_decode_time 86401 '1d 0h 0m 1s'
