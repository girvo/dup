import os
import net
import uri
import strutils

type
  DockerHost* = tuple[scheme: string, host: string, port: int, kind: HostKind]
  HostKind* = enum
    url, unix

# TODO: This needs to be cross-platform and cross-host, and configurable
proc getHost*(k: string = "DOCKER_HOST"): DockerHost =
  var
    host = if existsEnv(k): getEnv(k) else: "unix:///var/run/docker.sock"
    kind: HostKind = if host.startsWith("unix"): unix else: url

  if kind == unix:
    return (scheme: "unix", host: host.replace("unix://", ""), port: 0, kind: kind)

  var parsed = host.parseUri()

  if parsed.scheme == "":
    raise newException(IOError, "invalid scheme given from $" & $k & " environment variable: " & parsed.scheme)
  elif parsed.scheme == "unix":
    echo(parsed.path)
    quit()
  if parsed.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsed.port)
  if parsed.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsed.port)

  # Return our DockerHost tuple
  return (scheme: parsed.scheme, host: parsed.hostname, port: parseInt(parsed.port), kind: kind)

# proc connect*(host: DockerHost) =
#   var sock = newSocket($host)
#   var conn = sock.connect()
