import unittest

# Unit under test
import ../src/docker

# Test dependencies
import os
import optional_t
import net

# Core vars
let
  hostKey = "FAKE_DOCKER_HOST"
  unixHost: DockerHost = (scheme: "unix", host: "/var/run/docker.sock", port: 0, kind: unix)

suite "docker":
  setup:
    os.putEnv(hostKey, "tcp://127.0.0.1:2375")

  teardown:
    os.putEnv(hostKey, "")

  test "getHost parses TCP DOCKER_HOST correctly":
    let res: DockerHost = docker.getHost(hostKey)
    check (res.scheme == "tcp")
    check (res.port == 2375)
    check (res.host == "127.0.0.1")
    check (res.kind == url)

  test "getHost parses unix socket correctly":
    os.putEnv(hostKey, "unix:///var/run/docker.sock")
    let res: DockerHost = docker.getHost(hostKey)
    check (res.scheme == "unix")
    check (res.port == 0)
    check (res.host == "/var/run/docker.sock")
    check (res.kind == unix)

  test "connectToUnix raises exception on incorrect DockerHost":
    # var host: DockerHost = (scheme: "unix", host: "/var/run/docker.sock", port: 0, kind: unix)
    let host: DockerHost = (scheme: "tcp", host: "example.com", port: 80, kind: url)
    let result = docker.connectToUnix(host)
    check (isNone result)

  test "connectToUnix creates a socket for us to listen to":
    let sock = docker.connectToUnix(unixHost)
    check (isSome sock)

  test "INTEGRATION: connectToUnix can send to the socket":
    let sockOpt = docker.connectToUnix(unixHost)
    if sockOpt:
      # Pull the Socket out of the optional
      let sock = get sockOpt
      sock.send("GET / HTTP/1.1\r\n")
    else:
      check (false)
