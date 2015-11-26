let doc = """
Declaratively define and run stateful Docker containers for web development.

Usage:
  dup up
  dup down
  dup init
  dup status
  dup build [--no-cache]
  dup (-h | --help)
  dup --version
"""

import os
import strutils
import docopt

let args = docopt(doc, version = "Docker Up 0.1")

const dupFile = ".up.json"

proc checkDupFile() =
  let currDir = getCurrentDir()
  if not existsFile(currDir / dupFile):
    echo("Missing \".up.json\" in current directory.")
    quit(1)

checkDupFile()
