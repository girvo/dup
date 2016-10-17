## docker.nim tests

import unittest
import options
import typetraits
import ../src/private/types

# Unit under test
import ../src/docker

suite "docker.parseVersionStr":
  setup: discard
  teardown: discard

  test "works with regular version strings":
    let vstr = "1.12.1,"
    let result = docker.parseVersionStr(vstr)
    check(result.isSome())
    check(result.get().major == 1)
    check(result.get().minor == 12)
    check(result.get().patch == 1)

  test "works with extraneous data":
    let vstr = "1.12.1ljkalkjsalksalka"
    let result = docker.parseVersionStr(vstr)
    check(result.isSome())
    check(result.get().major == 1)
    check(result.get().minor == 12)
    check(result.get().patch == 1)
