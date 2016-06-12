## Core functions wrapping around the Docker remote API for Dup and Duploy

import os, strutils, future
import fp/option
import docker

proc hello*() =
  var testing = Some("testing")
  echo testing.map((input: string) -> string =>
    input & "!!").map((input: string) -> string =>
      input & "??")
  echo get testing
