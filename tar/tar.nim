## tar.nim
##
## TAR archive implementation in Nim, matching OSDev's definition. This is
## only for packing, only the subset needed for Docker's image handling
##
## See: http://wiki.osdev.org/Tar

# Core dependencies
import os
import posix
import strutils
import fp/option
import utils/binary

# Third-party & custom dependencies
from tar_header as tar import nil

proc statTesting*() : Stat =
  discard stat("./testing.txt", result)

proc rpad*(str: string, len: Natural, pad: char = '\0') : string =
  result = ""
  let strLen = len(str)
  let diff = len - strLen
  if diff > 0:
    result = str & repeat(pad, diff)

proc headerPtrTest*() : void =
  var header = newPtr[uint8](512)
  var fname = newPtr[uint8]("./testing.txt")
  var nextOffset = 0
  var currentLen = 100
  header[0].copyFrom(fname[0])
  discard

proc main*() : void =
  # Lets craft a TAR header
  var file = open ("/tmp/me.tar", fmWrite)
  # Filename and stat
  var fname = "./testing.txt"
  var testing: Stat
  discard stat(fname, testing)
  var newfname = fname.rpad(Natural(100))
  discard file.writeChars(newfname, 0, Natural(100))
  # file mode
  var mode = rpad($testing.st_mode, Natural(8))
  discard file.writeChars(mode, 100, Natural(8))
  # user ID
  var uid = rpad($testing.st_uid, Natural(8))
  discard file.writeChars(uid, 108, Natural(8))
  # group ID
  var gid = rpad($testing.st_gid, Natural(8))
  discard file.writeChars(gid, 116, Natural(8))
  # close our "tar"
  close (file)

proc main (): int =
  var fh = open ("./output.bin", fmWrite)
  var written = writeChars(f=fh, a="HAH", 0, Natural(3))
  echo ($written)
  result = 0

quit main()
