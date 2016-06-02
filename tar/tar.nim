## tar.nim
##
## TAR archive implementation in Nim, maching OSDev's definition. This is
## only for packing, only the subset needed for Docker's image handling
##
## See: http://wiki.osdev.org/Tar

import os
import asyncfile
import tar_header as tar

proc main () =
  var test = tar.Header()

main()
