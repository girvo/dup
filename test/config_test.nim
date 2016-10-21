## config.nim tests

import unittest
import options
import typetraits
import ../src/private/types

# Unit under test
import ../src/config

suite "config.argsToStr":
  setup: discard
  teardown: discard

  test "works with BuildArgs":
    let args: BuildArgs = @[newArg("example", "value")]
    let result = buildArgsToStr(args)
    check(result == " --build-arg example=value")

  test "works with Args":
    let args: Args = @[newArg("example2", "value2")]
    let result = argsToStr(args)
    check(result == " -e example2=value2")
