import unittest

# Unit under test
import ../src/docker

# Test dependencies
import os

# Core vars
let
  hostKey = "FAKE_DOCKER_HOST"

suite "docker":
  setup:
    os.putEnv(hostKey, "tcp://127.0.0.1:2375")

  teardown:
    os.putEnv(hostKey, "")

  test "getHost parses TCP DOCKER_HOST correctly":
    var res: DockerHost = docker.getHost(hostKey)
    check(res.scheme == "tcp")
    check(res.port == 2375)
    check(res.host == "127.0.0.1")
    check(res.kind == url)

  test "getHost parses unix socket correctly":
    os.putEnv(hostKey, "unix:///var/run/docker.sock")
    var res: DockerHost = docker.getHost(hostKey)
    check(res.scheme == "unix")
    check(res.port == 0)
    check(res.host == "/var/run/docker.sock")
    check(res.kind == unix)

  test "connectToHost":
    os.putEnv(hostKey, "tcp://192.168.64.2:2375")
    docker.connectToHost(docker.getHost())
    check(0 == 1)
