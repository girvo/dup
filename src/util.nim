## Useful utility procs
##
## Author: Josh Girvin <josh@jgirvin.com>
## License: MIT

import random
import net
import terminal
import random

import private/types
import database
import config

proc errMissingKey*(key: string, shouldQuit: bool = false) =
  echo("Error: Your \".up.json\" file is missing the \"" & key & "\" key")
  if shouldQuit: quit(252)

proc getAndCheckRandomPort*(): int =
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

## Writes out a given name and status boolean pair
## "true": running (green)
## "false": not running (red)
proc writeStatus*(name: string, status: bool) =
  writeStyled(name)
  if status:
    setForegroundColor(fgGreen)
    stdout.write("running")
  else:
    setForegroundColor(fgRed)
    stdout.write("not running")
  resetAttributes()
  stdout.write("\n")
