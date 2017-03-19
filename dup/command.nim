## Command procs
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import osproc
import strutils
import docopt

import private/types
import database
import config
import util
import container

proc needsInit*(conf: ProjectConfig) =
  ## TODO: Refactor this to be a pragma applied to command procs
  if conf.dbConf.kind == None: return
  if not hasDataContainerBeenBuilt(conf):
    writeError("Dup has not been initialised. Run 'dup init'")
    quit(252)

## Initialise the database
proc init*(conf: ProjectConfig) {.raises: [].} =
  if hasDataContainerBeenBuilt(conf):
    ## Exit out if there already is an .up.state file
    writeError("Docker Up has already been initalised\n")
    writeMsg("To re-init your project, run the following command:")
    echo("  docker rm " & conf.data)
    quit(253)
  var
    command: string = ""
    shouldRunCommand: bool = false
  # Initialise the correct volume-only container based on configured kind
  case conf.dbConf.kind
  of MySQL:
    writeMsg("Initialising " & $conf.dbConf.kind & " volume-only container...")
    shouldRunCommand = true
    command = join([
      "docker run -d",
      "-v", quoteShellPosix(conf.dbConf.getVolumePath()),
      "--name", quoteShellPosix(conf.data),
      "--entrypoint", "/bin/echo",
      quoteShellPosix(conf.dbConf.getImageName())
    ], " ")
  of PostgreSQL:
    writeMsg("Initialising " & $conf.dbConf.kind & " volume-only container...")
    shouldRunCommand = true
    command = join([
      "docker run -d",
      "-v", quoteShellPosix(conf.dbConf.getVolumePath()),
      "--name", quoteShellPosix(conf.data),
      "-e POSTGRES_PASSWORD=" & quoteShellPosix(conf.dbConf.password),
      "-e POSTGRES_DB=" & quoteShellPosix(conf.dbConf.name),
      "-e POSTGRES_USER=" & quoteShellPosix(conf.dbConf.username),
      "--entrypoint", "/bin/echo",
      quoteShellPosix(conf.dbConf.getImageName())
    ], " ")
  of MongoDB:
    writeMsg("Initialising " & $conf.dbConf.kind & " volume-only container...")
    shouldRunCommand = true
    command = join([
      "docker run -d",
      "-v", quoteShellPosix(conf.dbConf.getVolumePath()),
      "--name", quoteShellPosix(conf.data),
      "--entrypoint", "/bin/echo",
      quoteShellPosix(conf.dbConf.getImageName()),
    ], " ")
  of None:
    writeMsg("No database requested. If you change this in the future, you will need to reinitialise your dup project")
    shouldRunCommand = false
  # Now check if we should build the state file, and run our command
  try:
    if shouldRunCommand == true:
      var exitCode = execCmd command
      if exitCode != 0:
        writeError("An error occurred while creating the volume-only container. See the above output for details")
        quit(exitCode)
    writeMsg("Done")
    quit(0)
  except:
    writeError("" & getCurrentExceptionMsg())
    quit(1)

## Checks the current status of each container and prints to stdout
proc printStatus*(conf: ProjectConfig) {.raises: [].} =
  try:
    var
      currrent = inspectContainer(conf.web)
    writeStatus("Web: ", isContainerRunning(currrent))
    if conf.dbConf.kind != None:
      currrent = inspectContainer(conf.db)
      writeStatus("DB:  ", isContainerRunning(currrent))
    quit(0)
  except:
    writeError(getCurrentExceptionMsg(), true)
    quit(1)

## Starts the web container, and database container if configured
proc up*(conf: ProjectConfig) {.raises: [].} =
  needsInit(conf)
  ## Start the DB container first, if any
  case conf.dbConf.kind
  of MySQL:
    startMysql(conf)
  of PostgreSQL:
    startPostgres(conf)
  of MongoDB:
    startMongo(conf)
  of None: discard

  ## Start the web container
  case conf.dbConf.kind
  of None:
    # Do a thing
    startWeb(conf, false)
  else:
    # Do a thing with a DB
    startWeb(conf, true)
  quit(0)

## Stops and removes the containers
proc down*(conf: ProjectConfig) {.raises: [].} =
  needsInit(conf)
  writeMsg("Stopping and removing running containers...")
  var
    # stopWeb timeout of zero to stop the container immediately
    stopWeb = "docker stop -t 0 " & conf.web
    # stopDb does not use a timeout to avoid data corruption
    stopDb = "docker stop " & conf.db
    # rmWeb and rmDb both use -v to remove the linked volumes, avoiding orphans
    rmWeb = "docker rm -v " & conf.web
    rmDb = "docker rm -v " & conf.db

  writeMsg("Stopping web server...")
  discard execCmd(stopWeb)

  if conf.dbConf.kind != None:
    writeMsg("Gracefully stopping database...")
    discard execCmd(stopDb)

  writeMsg("Removing web server...")
  discard execCmd(rmWeb)

  if conf.dbConf.kind != None:
    writeMsg("Removing database...")
    discard execCmd(rmDb)

  writeMsg("Done")
  quit(0)

## Builds the image, passing build arguments in
proc build*(conf: ProjectConfig, noCache: bool = false) =
  var hasEnv = false
  var buildArgs = buildArgsToStr(conf.buildArgs)
  for arg in conf.buildArgs:
    if arg.name == "env": hasEnv = true
  if not hasEnv:
    buildArgs &= " --build-arg env=dev"
  # Setup the build command
  let projectTag = conf.name & ":latest"
  let cacheOpt = if noCache: "--no-cache" else: ""
  let command = [
    "docker build",
    buildArgs,
    cacheOpt,
    "-f", conf.dockerfile,
    "-t", projectTag,
    "."
  ].join(" ")
  # Run the build command
  writeMsg("Building latest image...")
  writeCmd(command)
  let exitCode = execCmd(command)
  if exitCode != 0:
    quit(exitCode)
  writeMsg("Done")
  quit(0)

## Gives the user a shell prompt in the given container
proc bash*(conf: ProjectConfig, args: Table[string, docopt.Value]) =
  if args["web"]:
    writeMsg("Entering web server container...")
    discard execCmd("docker exec -it " & conf.web & " bash")
    quit(0)
  if args["db"]:
    if conf.dbConf.kind == None:
      writeMsg("No database container exists for this project")
      quit(0)
    writeMsg("Entering database container...")
    discard execCmd("docker exec -it " & conf.db & " bash")
    quit(0)
  # Default case
  writeError("You must specify which container: \"dup bash web\" or \"dup bash db\"")
  quit(250)

## Accesses the database's SQL prompt via docker exec
proc sql*(conf: ProjectConfig) =
  case conf.dbConf.kind
  of MySQL:
    discard execCmd("docker exec -it " & conf.db & " mysql")
    quit(0)
  of PostgreSQL:
    discard execCmd("docker exec -it -u postgres " & conf.db & " psql")
    quit(0)
  of MongoDB:
    discard execCmd("docker exec -it " & conf.db & " mongo")
    quit(0)
  of None:
    writeError("No database configured for this project")
    quit(251)

proc logs*(conf: ProjectConfig, args: Table[string, docopt.Value]) {.raises: [].} =
  if args.getOrDefault("web"):
    discard execCmd("docker logs -f " & conf.web)
    echo("") # Newline for TTY handling
    quit(0)
  if args.getOrDefault("db"):
    discard execCmd("docker logs -f " & conf.db)
    echo("") # Newline for TTY handling
    quit(0)
  writeError("You must specify which container: 'dup sql web' or 'dup sql db'")
  quit(250)
