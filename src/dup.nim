## dup: a managed local Docker web development tool
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import os
import osproc
import strutils
import json
import docopt
import random
import net
import terminal

import private/types
import database
import config

## Define our version constant for re-use
const version = "dup 1.0.0"

## Define our docopt parsing schema
let doc = """
Declaratively define and run stateful Docker containers for web development.

Usage:
  dup up
  dup down
  dup init
  dup status
  dup build [--no-cache]
  dup bash [web | db]
  dup sql
  dup (-h | --help)
  dup (-v | --version)
"""

## Parse command-line options with docopt.nim
let args = docopt(doc, version = version)

## Handle version printing ourselves
## This is done to solve a docopt parsing quirk, where short-opt "-v" can't be
## bound to "--version" properly. We need to do this first, to get around the
## .up.json and Dockerfile checks that are run immediately for other commands
if args["-v"] or args["--version"]:
  echo(version)
  quit(0)

const dupFile = ".up.json"
const stateFile = ".up.state"

var
  dbConf = newDBConfig(None) ## Default the database config to "None"
  newConf: ProjectConfig

proc errMissingKey(key: string, shouldQuit: bool = false) =
  echo("Error: Your \".up.json\" file is missing the \"" & key & "\" key")
  if shouldQuit: quit(252)

proc checkAndParseDupFile() {.raises: [].} =
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
    newConf = createProjectConfig(raw, dbConf)
  except DBConfigError:
    echo("Error: In 'db', " & getCurrentExceptionMsg())
    quit(251)
  except ProjectConfigError:
    echo("Error: In config, " & getCurrentExceptionMsg())
    quit(252)
  except:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(250)

proc checkDockerfile() {.raises: [].} =
  try:
    if not existsFile(getCurrentDir() / "Dockerfile"):
      echo("Error: Missing \"Dockerfile\" in current directory")
      quit(254)
  except OSError:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

proc checkStatefile(): bool {.raises: [].} =
  try:
    result = existsFile(getCurrentDir() / stateFile)
  except:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

proc buildStatefile() =
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

proc getAndCheckRandomPort(): int =
  ## Generates a random port number, checks whether it is open and returns the
  ## port if it is. Maximum cycle check of 10 to ensure we don't lock up the
  ## process unnecesarily
  proc generate(): int =
    ## Internal proc to generate a random port number from 1024..65534
    randomize()
    var port: int = random(65534) + 1024
    if port >= 65534:
        port = port - 1024
    return port

  proc check(port: int): bool =
    ## Internal proc to check whether a given port is free
    var free = false
    try:
      var sock = newSocket()
      sock.connect("localhost", Port(port))
      sock.close()
      free = true
    except:
      free = false
    return free
  var
    exposedPort = generate()   # Generate our first port
    count = 1                  # Init the cycle checker
  # Start our port checker loop
  while (check(exposedPort) == false) and (count <= 10):
    count = count + 1
    exposedPort = generate()
  # Final cycle checker exit
  if count <= 10:
    echo("Error: Could not find a free host port to bind to")
    quit(243)
  return exposedPort

proc startMysql(project: string, dbname: string, dbpass: string) =
  echo "Starting MySQL..."
  let chosenPort = getAndCheckRandomPort()
  let portFragment = $chosenPort & ":3306"
  let command = "docker run -d --name " & project & "-db --voluWemes-from " & project & "-data -e MYSQL_PASS=" & dbpass & " -e ON_CREATE_DB=" & dbname & " -p " & portFragment & " tutum/mysql"
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting MySQL failed. Check the output above")
    quit(exitCode)
  echo("Success: MySQL started, and exposed on host port " & $chosenPort)

proc startPostgres(project: string, dbname: string, dbuser: string, dbpass: string) =
  echo "Starting Postgres..."
  let chosenPort = getAndCheckRandomPort()
  let portFragment = $chosenPort & ":5432"
  let command = "docker run -d --name " & project & "-db --volumes-from " & project & "-data -e POSTGRES_PASSWORD=" & dbpass & " -e POSTGRES_DB=" & dbname & " -e POSTGRES_USER=" & dbuser & " -p " & portFragment & " postgres:9.5"
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting Postgres failed. Check the output above")
    quit(exitCode)
  echo("Success: Postgres started, and exposed on host port " & $chosenPort)

proc startWeb(project: string, portMapping="", folderMapping: string, env: Args, hasDB: bool = true) =
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

proc inspectContainer(containerName: string): JsonNode =
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
proc isContainerRunning(inspectNode: JsonNode): bool =
  if inspectNode.len == 0:
    return false
  let running = inspectNode[0]{"State", "Running"}
  if running == nil:
    return false
  return running.bval

## Writes out a given name and status boolean pair
## "true": running (green)
## "false": not running (red)
proc writeStatus(name: string, status: bool) =
  writeStyled(name)
  if status:
    setForegroundColor(fgGreen)
    stdout.write("running")
  else:
    setForegroundColor(fgRed)
    stdout.write("not running")
  resetAttributes()
  stdout.write("\n")

## Check our Dockerfile and .up.json files exist
## Bail out if they don't
checkDockerfile()
checkAndParseDupFile()

##
## Command definitions
##

## Initialise the database
## TODO: Refactor this to remove the need for a state-file, check the Docker
##       inspect output instead for the given container name
proc init(conf: ProjectConfig) {.raises: [].} =
  if checkStateFile():
    ## Exit out if there already is an .up.state file
    echo("Error: Docker Up has already been initalised")
    echo("To rebuild the data-volume container, remove the " & conf.data & " container, and delete the .up.state file.")
    quit(253)
  var
    command: string = ""
    shouldRunCommand: bool = false
  # Initialise the correct volume-only container based on configured kind
  case conf.dbConf.kind
  of MySQL:
    echo("Initialising " & $conf.dbConf.kind & " volume-only container..")
    shouldRunCommand = true
    command = join([
      "docker run -d -v",
      conf.dbConf.getVolumePath(),
      "--name",
      conf.data,
      "--entrypoint",
      "/bin/echo",
      conf.dbConf.getImageName()
    ], " ")
  of PostgreSQL:
    echo("Initialising " & $conf.dbConf.kind & " volume-only container..")
    shouldRunCommand = true
    command = join([
      "docker run -d -v",
      conf.dbConf.getVolumePath(),
      "--name",
      conf.data,
      "-e POSTGRES_PASSWORD=" & conf.dbConf.password,
      "-e POSTGRES_DB" & conf.dbConf.name,
      "-e POSTGRES_USER" & conf.dbConf.username,
      "--entrypoint",
      "/bin/echo",
      conf.dbConf.getImageName()
    ], " ")
  of None:
    echo("No database requested. If you change this in the future, you will need to reinitialise your dup project")
    shouldRunCommand = false
  else:
    echo("Error: Invalid database type specified in config")
    quit(252)
  # Now check if we should build the state file, and run our command
  try:
    if shouldRunCommand == true:
      var exitCode = execCmd command
      if exitCode != 0:
        echo("Error: An error occurred while creating the volume-only container. See the above output for details")
        quit(exitCode)
    buildStatefile()
    echo("Done")
    quit(0)
  except:
    echo("Error: " & getCurrentExceptionMsg())
    quit(1)

## Checks the current status of each container and prints to stdout
proc printStatus(conf: ProjectConfig) {.raises: [].} =
  try:
    var
      currrent = inspectContainer(conf.web)
    writeStatus("Web: ", isContainerRunning(currrent))
    if dbConf.kind != None:
      currrent = inspectContainer(conf.db)
      writeStatus("DB:  ", isContainerRunning(currrent))
    quit(0)
  except:
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

## Starts the web container, and database container if configured
proc up(conf: ProjectConfig) {.raises: [].} =
  if not checkStatefile():
    echo("Error: Docker Up has not been initialised. Run 'dup init'")
    quit(252)

  case conf.dbConf.kind
  of MySQL:
    startMysql(conf.name, conf.dbConf.name, conf.dbConf.password)
    startWeb(conf.name, conf.port, conf.volume, conf.envVars, true)
  of PostgreSQL:
    startPostgres(conf.name, conf.dbConf.name, conf.dbConf.username, conf.dbConf.password)
    startWeb(conf.name, conf.port, conf.volume, conf.envVars, true)
  else:
    # Start only the web container if we've got an invalid type (or None)
    startWeb(conf.name, conf.port, conf.volume, conf.envVars, false)
  quit(0)

## Stops and removes the containers
proc down(conf: ProjectConfig) {.raises: [].} =
  if not checkStatefile():
    echo("Error: Docker Up has not been initialised. Run \"dup init\"")
    quit(252)

  echo("Stopping and removing running containers...")
  var
    # stopWeb timeout of zero to stop the container immediately
    stopWeb = "docker stop -t 0 " & conf.web
    # stopDb does not use a timeout to avoid data corruption
    stopDb = "docker stop " & conf.db
    # rmWeb and rmDb both use -v to remove the linked volumes, avoiding orphans
    rmWeb = "docker rm -v " & conf.web
    rmDb = "docker rm -v " & conf.db

  echo("Stopping web server...")
  discard execCmd(stopWeb)

  if conf.dbConf.kind != None:
    echo("Gracefully stopping database...")
    discard execCmd(stopDb)

  echo("Removing web server...")
  discard execCmd(rmWeb)

  if conf.dbConf.kind != None:
    echo("Removing database...")
    discard execCmd(rmDb)

  echo("Done.")
  quit(0)

## Builds the image, passing build arguments in
proc build(conf: ProjectConfig) =
  var
    buildArgs = ""
    hasEnv = false
  for arg in conf.buildArgs:
    buildArgs &= " --build-arg " & arg.name & "=" & arg.value
    if arg.name == "env": hasEnv = true
  if not hasEnv:
    buildArgs &= " --build-arg env=dev"
  # Setup the build command
  let projectTag = conf.name & ":latest"
  let cacheOpt = if args["--no-cache"]: "--no-cache" else: ""
  let command = ["docker build", buildArgs, cacheOpt, "-f", conf.dockerfile, "-t", projectTag, "."].join(" ")
  # Run the build command
  echo("Building latest image...")
  let exitCode = execCmd(command)
  if exitCode != 0:
    quit(exitCode)
  echo("Done")
  quit(0)

## Gives the user a shell prompt in the given container
proc bash(conf: ProjectConfig) =
  if args["web"]:
    echo("Entering web server container...")
    discard execCmd("docker exec -it " & conf.web & " bash")
    quit(0)
  if args["db"]:
    if conf.dbConf.kind == None:
      echo("No database container exists for this project")
      quit(0)
    echo("Entering database container...")
    discard execCmd("docker exec -it " & conf.db & " bash")
    quit(0)
  # Default case
  echo("Error: You must specify which container: \"dup bash web\" or \"dup bash db\"")
  quit(250)

## Accesses the database's SQL prompt via docker exec
proc sql(conf: ProjectConfig) =
  case conf.dbConf.kind
  of MySQL:
    discard execCmd("docker exec -it " & conf.db & " mysql")
    quit(0)
  of PostgreSQL:
    discard execCmd("docker exec -it -u postgres " & conf.db & " psql")
    quit(0)
  of None:
    echo("Error: No database configured for this project")
    quit(251)

##
## Command bindings
##

if args["init"]: init(newConf)
if args["status"]: printStatus(newConf)  ## TODO: Refactor to allow for JSON output
if args["up"]: up(newConf)
if args["down"]: down(newConf)
if args["build"]: build(newConf)
if args["bash"]: bash(newConf)
if args["sql"]: sql(newConf)
