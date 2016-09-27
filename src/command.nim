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

## Initialise the database
## TODO: Refactor this to remove the need for a state-file, check the Docker
##       inspect output instead for the given container name
proc init*(conf: ProjectConfig) {.raises: [].} =
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
    echo("Initialising " & $conf.dbConf.kind & " volume-only container...")
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
    echo("Initialising " & $conf.dbConf.kind & " volume-only container...")
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
  of MongoDB:
    echo("Initialising " & $conf.dbConf.kind & " volume-only container...")
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
  of None:
    echo("No database requested. If you change this in the future, you will need to reinitialise your dup project")
    shouldRunCommand = false
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
    echo("Fatal: " & getCurrentExceptionMsg())
    quit(1)

## Starts the web container, and database container if configured
proc up*(conf: ProjectConfig) {.raises: [].} =
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
  of MongoDB:
    startMongo(conf)
    startWeb(conf.name, conf.port, conf.volume, conf.envVars, true)
  of None:
    # Start only the web container if we've got an invalid type (or None)
    startWeb(conf.name, conf.port, conf.volume, conf.envVars, false)
  quit(0)

## Stops and removes the containers
proc down*(conf: ProjectConfig) {.raises: [].} =
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
proc build*(conf: ProjectConfig, noCache: bool = false) =
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
  let cacheOpt = if noCache: "--no-cache" else: ""
  let command = ["docker build", buildArgs, cacheOpt, "-f", conf.dockerfile, "-t", projectTag, "."].join(" ")
  # Run the build command
  echo("Building latest image...")
  let exitCode = execCmd(command)
  if exitCode != 0:
    quit(exitCode)
  echo("Done")
  quit(0)

## Gives the user a shell prompt in the given container
proc bash*(conf: ProjectConfig, args: Table[string, docopt.Value]) =
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
    echo("Error: No database configured for this project")
    quit(251)

proc logs*(conf: ProjectConfig, args: Table[string, docopt.Value]) {.raises: [].} =
  if args.getOrDefault("web"):
    discard execCmd("docker logs -f " & conf.web)
    quit(0)
  if args.getOrDefault("db"):
    discard execCmd("docker logs -f " & conf.db)
    quit(0)
  echo("Error: You must specify which container: 'dup sql web' or 'dup sql db'")
  quit(250)
