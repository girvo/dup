import os
import net
import uri
import strutils

type DockerHost* = tuple[scheme: string, host: string, port: int]

# TODO: This needs to be cross-platform and cross-host, and configurable
proc getHost*(k: string = "DOCKER_HOST"): DockerHost =
  var
    host = if existsEnv(k): getEnv(k) else: "unix:///var/run/docker.sock"
    parsedUri = parseUri(host)

  if parsedUri.scheme == "":
    raise newException(IOError, "invalid scheme given from $" & $k & " environment variable: " & parsedUri.scheme)
  if parsedUri.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsedUri.port)
  if parsedUri.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsedUri.port)

  # Return our DockerHost tuple
  return (scheme: parsedUri.scheme, host: parsedUri.hostname, port: parseInt(parsedUri.port))

# proc connect*(host: DockerHost) =
#   var sock = newSocket($host)
#   var conn = sock.connect()
