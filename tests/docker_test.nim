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
        os.putEnv(hostKey, "https://127.0.0.1:8080")

    teardown:
        os.putEnv(hostKey, "")

    test "getHost pulls DOCKER_HOST if available":
        var res: DockerHost = docker.getHost(hostKey)
        check(res.scheme == "https")
