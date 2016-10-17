## Docker client
##
## Author: Josh Girvin
## License: MIT

import osproc
import strutils
import sequtils
import nre
import json
import options

import private/types
import util

proc exitWithErr(output: string, exitCode: int) {.raises: [].} =
  ## Internal proc for exiting with a stdout/exit-code tuple from execCmdEx
  writeError("Error checking Docker client version, please check output below", true)
  echo(output)
  quit(exitCode)

proc parseVersionStr*(vstr: string): Option[VersionNumber] {.noSideEffect.} =
  let
    version = re"^(\d+)\.(\d+)\.(\d+).*$"
    parsed = vstr.find(version)
    matched = parsed.isSome()
  if matched:
    let
      major = parsed.get().captures[0]
      minor = parsed.get().captures[1]
      patch = parsed.get().captures[2]
    result = some newVersionNumber(
      parseInt(major),
      parseInt(minor),
      parseInt(patch))

proc getVersion*(): VersionNumber =
  let
    command = join([
      "docker",
      "-v"
    ], " ")
  var
    output: string
    exitCode: int
  try:
    (output, exitCode) = execCmdEx(command)
    if exitCode != 0: exitWithErr(output, exitCode)
  except:
    exitWithErr(getCurrentExceptionMsg(), 1)
  if exitCode != 0:
    writeError("Error checking Docker client version, please check output below", true)
    echo(output)
    quit(exitCode)
  var versionStr = split(output, ' ')[2]
  if versionStr == nil:
    versionStr = ""
  let parsed = versionStr.parseVersionStr()
  if parsed.isNone():
    exitWithErr("versionStr = " & versionStr, 3)
  result = parsed.get()
