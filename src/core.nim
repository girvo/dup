## Core functions wrapping around the Docker remote API for Dup and Duploy

import os, strutils, future
import fp/option
import docker

proc hello*() : void =
  var theThing: Option[string] = Some("testing")
  echo theThing.map((input: string) -> string =>
    input & "!!").map((input: string) -> string =>
      input & "??")
  echo get theThing
