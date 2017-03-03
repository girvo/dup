## util.nim tests

import unittest
import options
import typetraits
import ../src/private/types

# Unit under test
import ../src/util

suite "util.isVersionTooOld":
  setup: discard
  teardown: discard

  test "fails with incorrect major":
    let version = newVersionNumber(0, 12, 0)
    let result = isVersionTooOld(version)
    check(result == true)

  test "fails with correct major, incorrect minor":
    let version = newVersionNumber(1, 11, 0)
    let result = isVersionTooOld(version)
    check(result == true)

  test "passes with correct major/minor for version v1":
    let version = newVersionNumber(1, 13, 0)
    let result = isVersionTooOld(version)
    check(result == false)

  test "passes with correct major/minor for new release numbers":
    let version = newVersionNumber(17, 3, 0)
    let result = isVersionTooOld(version)
    check(result == false)
