import os
import net
import uri

# TODO: This needs to be cross-platform and cross-host
# TODO: This also needs to be configurable
proc getHost*(k: string = "DOCKER_HOST") =
    var host = ""
    if existsEnv(k):
        host = getEnv(k)
    else:
        host = "unix:///var/run/docker.sock"
    var parsed = parseUri(host)
    echo($parsed)

# proc connect*(host: DockerHost) =
#     var sock = newSocket($host)
#     var conn = sock.connect()
