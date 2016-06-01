## tar.nim
## TAR archive implementation in Nim, maching OSDev's definition. This is
## only for packing, only the subset needed for Docker's image handling
## See: http://wiki.osdev.org/Tar

import os

type
  Header* {.packed.} = object #\
    ## TAR hader, a packed struct (-ish) of chars
    filename*: array[100, char]
    mode*: array[8, char]
    uid*: array[8, char]
    gid*: array[8, char]
    size*: array[12, char]
    mtime*: array[12, char]
    chksum*: array[8, char]
    typeflag*: array[1, char]
