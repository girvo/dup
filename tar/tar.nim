## tar.nim
##
## TAR archive implementation in Nim, maching OSDev's definition. This is
## only for packing, only the subset needed for Docker's image handling
##
## See: http://wiki.osdev.org/Tar

import os

{.compile: "sltar.c".}
proc compress(p: cstring): cint {.importc.}

proc main () =
  var
    argc = paramCount()
  for i in 1..argc:
    var p: cstring = paramStr(i)
    discard compress(p)

when isMainModule:
  main()
