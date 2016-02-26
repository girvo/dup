import os
import net
import uri
import strutils

type DockerHost* = tuple[scheme: string, host: string, port: int]

# Exception types
type DockerHostParseError = IOError

# TODO: This needs to be cross-platform and cross-host
# TODO: This also needs to be configurable
proc getHost*(k: string = "DOCKER_HOST"): DockerHost =
    var host = ""
    if existsEnv(k):
        host = getEnv(k)
    else:
        host = "unix:///var/run/docker.sock"
    var parsedUri = parseUri(host)
    if parsedUri.scheme == "":
        raise newException(DockerHostParseError, "invalid scheme given from $" & $k & " environment variable")
    return (scheme: parsedUri.scheme, host: parsedUri.hostname, port: parseInt(parsedUri.port))

# proc connect*(host: DockerHost) =
#     var sock = newSocket($host)
#     var conn = sock.connect()
