version = "1.0.7"
author = "Josh Girvin <josh@jgirvin.com>, Nathan Craike <me@ncraike.com>"
description = "CLI wrapper for local Docker web development"
license = "MIT"

# Dependencies
requires "nim >= 0.14.3"
requires "docopt >= 0.6.2"
requires "jsonob >= 0.1.0"

# Config
binDir = "build"
srcDir = "dup"
bin = @["dup"]

skipDirs = @["docker_socket"]
