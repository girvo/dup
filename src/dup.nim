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
  dup --version
"""

import os
import osproc
import strutils
import json
import docopt

let args = docopt(doc, version = "Docker Up v0.2.0")

const dupFile = ".up.json"
const stateFile = ".up.state"

proc checkDupFile(): JsonNode =
  if not existsFile(getCurrentDir() / dupFile):
    echo("Error: Missing \".up.json\" in current directory.")
    quit(255)

  let conf = json.parseFile(getCurrentDir() / dupFile)
  if not conf.hasKey("project"):
    echo("Error: Your \".up.json\" file is missing the \"project\" key.")
    quit(252)
  if not conf.hasKey("port"):
    echo("Error: Your \".up.json\" file is missing the \"port\" key.")
    quit(252)
  if not conf.hasKey("db"):
    echo("Error: Your \".up.json\" file is missing the \"db\" key.")
    quit(252)
  if not conf["db"].hasKey("type"):
    echo("Error: Missing \"type\" key in \"db\".")
  return conf

proc checkDockerfile() =
  if not existsFile(getCurrentDir() / "Dockerfile"):
    echo("Error: Missing \"Dockerfile\" in current directory.")
    quit(254)

proc checkStatefile(): bool =
  return existsFile(getCurrentDir() / stateFile)

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

proc startMysql(project: string, dbname: string, dbpass: string) =
  echo "Starting MySQL..."
  let command = "docker run -d --name " & project & "-db --volumes-from " & project & "-data -p 3306:3306 -e VIRTUAL_HOST=" & project & ".docker -e MYSQL_PASS=" & dbpass & " -e ON_CREATE_DB=" & dbname & " tutum/mysql"
  let exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting MySQL failed. Check the output above.")

proc startWeb(project: string, portMapping: string, hasDB: bool = true) =
  echo "Starting web server..."
  let
    link = if hasDB: "--link " & project & "-db:db "
               else: ""
    command = "docker run -d --name " & project & "-web -p " & portMapping & " -v $(pwd)/code:/var/www " & link & project & ":latest"
    exitCode = execCmd command
  if exitCode != 0:
    echo("Error: Starting web server failed. Check the output above.")

# Check our Dockerfile and .up.json files exist
checkDockerfile()
let config = checkDupFile()

###
# Command definitions
##
##
if args["init"]:
  if checkStateFile():
    echo("Error: Docker Up has already been initalised.")
    echo("To rebuild the data-volume container, remove the " & config["project"].getStr() & "-data container, and delete the .up.state file.")
    quit(253)

  case config["db"]["type"].getStr():
  of "mysql":
    echo("Initialising MySQL volume-only container...")
    let command = "docker run -d -v /var/lib/mysql --name " & config["project"].getStr() & "-data --entrypoint /bin/echo tutum/mysql"
    let (output, exitCode) = execCmdEx command

    case exitCode:
    of 0:
      buildStateFile()
      echo("Done.")
      quit(0)
    else:
      echo("An error occurred!See the following for details:" & output)
      quit(exitCode)
  of "none":
    echo("No database requested. If you change this in the future, you will need to reinitialise your dup project.")
    buildStateFile()
    quit(0)
  else:
    echo("Error: Invalid database type specified in config.")
    quit(252)
  quit(0)

###
# dup up
##
if args["up"]:
  if not checkStatefile():
    echo("Error: Docker Up has not been initialised. Run \"dup init\".")
    quit(252)

  case config["db"]["type"].getStr():
  of "mysql":
    startMysql(config["project"].getStr(), config["db"]["name"].getStr(), config["db"]["pass"].getStr())
    startWeb(project = config["project"].getStr(), portMapping = config["port"].getStr(), hasDB = true)
  of "none":
    startWeb(project = config["project"].getStr(), portMapping = config["port"].getStr(), hasDB = false)
  else:
    echo("Not implemented yet.")
    quit(252)
  quit(0)

if args["down"]:
  if not checkStatefile():
    echo("Error: Docker Up has not been initialised. Run \"dup init\".")
    quit(252)

  echo("Stopping and removing running containers...")
  var
    stopWeb = "docker stop " & config["project"].getStr() & "-web"
    stopDb = "docker stop " & config["project"].getStr() & "-db"
    rmWeb = "docker rm " & config["project"].getStr() & "-web"
    rmDb = "docker rm " & config["project"].getStr() & "-db"

  echo("Stopping web server..")
  discard execCmd(stopWeb)

  if config["db"]["type"].getStr() != "none":
    echo("Stopping database...")
    discard execCmd(stopDb)

  echo("Removing web server...")
  discard execCmd(rmWeb)

  if config["db"]["type"].getStr() != "none":
    echo("Removing database...")
    discard execCmd(rmDb)

  echo("Done.")
  quit(0)

if args["build"]:
  echo("Building latest image...")
  var command = ""
  if args["--no-cache"]:
    command = "docker build --no-cache -t " & config["project"].getStr() & ":latest ."
  else:
    command = "docker build -t " & config["project"].getStr() & ":latest ."

  let exitCode = execCmd(command)
  if exitCode != 0:
    quit(exitCode)
  echo("Done.")
  quit(0)

if args["status"]:
  echo("Yet to be implemented.")
  quit(0)

if args["bash"]:
  if args["web"]:
    echo("Entering web server container...")
    discard execCmd("docker exec -it " & config["project"].getStr() & "-web bash")
    quit(0)
  if args["db"]:
    if config["db"]["type"].getStr() == "none":
      echo("No database container exists for this project.")
      quit(0)
    echo("Entering database container...")
    discard execCmd("docker exec -it " & config["project"].getStr() & "-db bash")
    quit(0)
  # Default case
  echo("Error: You must specify which container: \"dup bash web\" or \"dup bash db\"")
  quit(250)

if args["sql"]:
  case config["db"]["type"].getStr():
  of "mysql":
    discard execCmd("docker exec -it " & config["project"].getStr() & "-db mysql")
    quit(0)
  else:
    echo("Not implemented yet.")
    quit(252)
