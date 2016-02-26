import os

proc getHost*(k: string = "DOCKER_HOST"): string =
    var host = ""
    if existsEnv(k):
        host = getEnv(k)
    else:
        host = "unix:///var/run/docker.sock"
    return host
