## Core functions wrapping around the Docker remote API for Dup and Duploy

import os, strutils
import optional_t
import docker

proc hello* () =
  var theThing: Option[string] = Some("testing")
  echo theThing.map(proc (input: string): string =
    input & "!!").map(proc (input: string): string =
      input & "?")
  echo get theThing
