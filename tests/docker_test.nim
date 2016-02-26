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

  test "getHost pulls DOCKER_HOST if available":
    var res: DockerHost = docker.getHost(hostKey)
    check(res.scheme == "tcp")
    check(res.port == 2375)
    check(res.host == "127.0.0.1")
