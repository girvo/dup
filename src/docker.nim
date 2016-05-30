## docker.nim
## Core Docker API client library using TCP/Unix sockets
## I'm stealing some of the ideas from this library:
## https://github.com/je-nunez/Docker_API_in_BASH/blob/master/docker_low_level_library.sh

import os
import net
import uri
import strutils
import optional_t

type
  DockerHost* = tuple
    [scheme: string, host: string, port: int, kind: HostKind]
  HostKind* = enum
    url, unix

type
  DockerError* = object of Exception

proc `$` (d: DockerHost): string =
  return d.scheme & "://" & d.host & ":" & $d.port

# TODO: This needs to be cross-platform and cross-host, and configurable
proc getHost*(k: string = "DOCKER_HOST"): DockerHost =
  var host = "unix:///var/run/socker.dock"
  var kind = unix

  if (existsEnv(k)):
    host = getEnv(k)
  else:
    echo ("Info: No DOCKER_HOST env var defined, defaulting to unix socket...")
  if (host.startsWith("unix")): kind = unix else: kind = url

  if kind == unix:
    return (scheme: "unix", host: host.replace("unix://", ""), port: 0, kind: kind)

  var parsed = host.parseUri()
  if parsed.scheme == "":
    raise newException(IOError, "invalid scheme given from $" & $k & " environment variable: " & parsed.scheme)
  if parsed.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsed.port)
  if parsed.port == "":
    raise newException(IOError, "invalid port given from $" & $k & " environment variable" & parsed.port)

  # Return our DockerHost tuple
  return (scheme: parsed.scheme, host: parsed.hostname, port: parseInt(parsed.port), kind: kind)

proc connectToUnix*(host: DockerHost): Option[Socket] =
  if host.kind != unix:
    ## Return out if we've got the wrong host kind
    return None[Socket]()
  let sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  try:
    sock.connectUnix(host.host)
  except OSError:
    echo ("Socket Error: Can't connect to the Docker socket at '" & host.host & "'")
    return None[Socket]()
  except:
    echo ("Fatal Error: An unexpected error occurred")
    return None[Socket]()
  return Some(sock)

proc sendToSocket*(sockOpt: Option[Socket], meth: string, path: string): Option[string] =
  if not sockOpt:
    return None[string]()
  var
    sock = get sockOpt
    cont = true
    captureBody = false
  # Send the request off to the Socket
  sock.send(meth & " " & path & " HTTP/1.0\r\n\n")
  try:
    var res = ""
    while cont:
      var buf = ""
      sock.readLine(buf, 500)
      if buf == "":
        cont = false
      if buf == "\r\n":
        captureBody = true
        continue
      if captureBody and cont:
        res = res & buf & "\n"
    var stripped = strip(s=(res), trailing=true, chars=NewLines)
    return Some[string](stripped)
  except:
    return None[string]()
