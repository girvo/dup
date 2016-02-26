import unittest

# Unit under test
import ../src/docker

# Test dependencies
import os

suite "docker":
    test "getHost pulls DOCKER_HOST if available":
        var hostKey = "FAKE_DOCKER_HOST"

        # Temporarily putEnv for our fake docker host
        os.putEnv(hostKey, "testing")
        var res = docker.getHost(hostKey)
        os.putEnv(hostKey, "")
        check(res == "testing")
