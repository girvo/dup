## dup: a managed local Docker web development tool
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import docopt

import private/types
import command
import util
from docker import getVersion
from database import newDBConfig
from container import checkDockerfile, checkAndParseDupFile

## Define our version constant for re-use
const version = "dup 1.0.5"

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
  dup logs [web | db]
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

var
  dbConf = newDBConfig(None) ## Default the database config to "None"
  conf: ProjectConfig ## Configuration ref object

## Check Docker version, bail-out if it's not 1.12.x or 1.13.x
let
  dv = docker.getVersion()
  isWrong = if dv.major == 1 and (dv.minor == 12 or dv.minor == 13): false else: true
if isWrong:
  writeError("Please install Docker >= v1.12.0", true)
  quit(5)

## Check our Dockerfile and .up.json files exist
## Bail out if they don't
checkDockerfile()
checkAndParseDupFile(dbConf, conf)

##
## Command bindings
##

if args["init"]: init(conf)
if args["status"]: printStatus(conf)  ## TODO: Refactor to allow for JSON output
if args["up"]: up(conf)
if args["down"]: down(conf)
if args["build"]: build(conf, args["--no-cache"])
if args["bash"]: bash(conf, args)
if args["sql"]: sql(conf)
if args["logs"]: logs(conf, args)
