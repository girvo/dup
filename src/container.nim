## Docker container management
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import os
import osproc
import json

import private/types
import database
import config
import util

const dupFile* = ".up.json"
const stateFile* = ".up.state"

proc checkAndParseDupFile*(dbConf: var DatabaseConfig, conf: var ProjectConfig) {.raises: [].} =
  try:
    if not existsFile(getCurrentDir() / dupFile):
      echo("Error: No '.up.json' found in current directory")
      quit(255)
    var raw = json.parseFile(getCurrentDir() / dupFile)
    if not raw.hasKey("project"):
      errMissingKey("project", true)
    if not raw.hasKey("db"):
      errMissingKey("db", true)
    # Set our heap-allocated config variables
    dbConf = newDBConfig(raw["db"])
    conf = createProjectConfig(raw, dbConf)
  except DBConfigError:
    echo("Error: In 'db', " & getCurrentExceptionMsg())
    quit(251)
  except ProjectConfigError:
    echo("Error: In config, " & getCurrentExceptionMsg())
    quit(252)
  except:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(250)

proc checkDockerfile*() {.raises: [].} =
  try:
    if not existsFile(getCurrentDir() / "Dockerfile"):
      echo("Error: Missing \"Dockerfile\" in current directory")
      quit(254)
  except OSError:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

proc checkStatefile*(): bool {.raises: [].} =
  try:
    result = existsFile(getCurrentDir() / stateFile)
  except:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

proc buildStatefile*() =
  echo("Building .up.state file...")
  open(getCurrentDir() / stateFile, fmWrite).close()
  if existsFile(getCurrentDir() / ".gitignore"):
    var
      hasLine: bool = false
      o = open(getCurrentDir() / ".gitignore", fmRead)

    for line in o.lines:
      if line == ".up.state":
        hasLine = true
    o.close()

    if not hasLine:
      echo("Appending .up.state to .gitignore...")
      var a = open(getCurrentDir() / ".gitignore", fmAppend)
      a.writeLine(".up.state")
      a.close()

proc startMysql*(project: string, dbname: string, dbpass: string) =
  echo "Starting MySQL..."
  let chosenPort = getAndCheckRandomPort()
  let portFragment = $chosenPort & ":3306"
  let command = "docker run -d --name " & project & "-db --voluWemes-from " & project & "-data -e MYSQL_PASS=" & dbpass & " -e ON_CREATE_DB=" & dbname & " -p " & portFragment & " tutum/mysql"
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting MySQL failed. Check the output above")
    quit(exitCode)
  echo("Success: MySQL started, and exposed on host port " & $chosenPort)

proc startPostgres*(project: string, dbname: string, dbuser: string, dbpass: string) =
  echo "Starting Postgres..."
  let chosenPort = getAndCheckRandomPort()
  let portFragment = $chosenPort & ":5432"
  let command = "docker run -d --name " & project & "-db --volumes-from " & project & "-data -e POSTGRES_PASSWORD=" & dbpass & " -e POSTGRES_DB=" & dbname & " -e POSTGRES_USER=" & dbuser & " -p " & portFragment & " postgres:9.5"
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting Postgres failed. Check the output above")
    quit(exitCode)
  echo("Success: Postgres started, and exposed on host port " & $chosenPort)

proc startWeb*(project: string, portMapping="", folderMapping: string, env: Args, hasDB: bool = true) =
  ## TODO: Refactor to leverage the config object instead of raw properties
  echo "Starting web server..."
  let
    link = if hasDB: "--link " & project & "-db:db " else: ""
    folder = if folderMapping == "": "-v $PWD/code:/var/www " else: "-v $PWD/" & folderMapping & " "
    port = if portMapping == "": " " else: "-p " & portMapping & " "
    command = "docker run -d -h " & project & ".docker --name " & project & "-web " & port & $env & " " & folder & link & " -e TERM=xterm-256color -e VIRTUAL_HOST=" & project & ".docker " & project & ":latest"
  echo command
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting web server failed. Check the output above")

proc inspectContainer*(containerName: string): JsonNode =
  try:
    let (output, exitCode) = execCmdEx("docker inspect " & containerName)
    if exitCode != 0:
      raise newException(IOError, "docker-inspect failed")
    result = parseJson(output)
  except:
    result = parseJson("[]")

## Checks the result of "docker inspect <container-name>" to see if it's running
## Assumes that the first object in the array returned by "inspect" is the
## container in question. Uses `return` to short-circuit the proc as needed
proc isContainerRunning*(inspectNode: JsonNode): bool =
  if inspectNode.len == 0:
    return false
  let running = inspectNode[0]{"State", "Running"}
  if running == nil:
    return false
  return running.bval
