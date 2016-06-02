## tar_header.nim
##
## Header definitions for the TAR implementation

const
  RECORDSIZE* = 512 ## Pads out header with zeroes to RECORDSIZE, in bytes
  NAMSIZ* = 100 ## Size of the filename field, in bytes
  TUNMLEN* = 32 ## uname size, in bytes
  TGNMLEN* = 32 ## gname size, in bytes

type
  Header* {.packed.} = object #\
    ## TAR hader, a packed struct (-ish) of chars, that adds up to RECORDSIZE
    filename: array[NAMSIZ, char]
    mode: array[8, char]
    uid: array[8, char]
    gid: array[8, char]
    size: array[12, char]
    mtime: array[12, char]
    chksum: array[8, char]
    linkflag: char
    linkname: array[NAMSIZ, char]
    magic: array[8, char]
    uname: array[TUNMLEN, char]
    gname: array[TGNMLEN, char]

  Record* = object {.union.}
    charptr*: array[RECORDSIZE, char]
    header*: Header

## The checksum field is filled with this while the checksum is computed.
const
  CHKBLANKS* = "        "

## The magic field is filled with this if uname and gname are valid.
const
  TMAGIC* = "ustar  "

## The magic field is filled with this if this is a GNU format dump entry
const
  GNUMAGIC* = "GNUtar "

## The linkflag defines the type of file
const
  LF_OLDNORMAL* = '\0'
  LF_NORMAL* = '0'
  LF_LINK* = '1'
  LF_SYMLINK* = '2'
  LF_CHR* = '3'
  LF_BLK* = '4'
  LF_DIR* = '5'
  LF_FIFO* = '6'
  LF_CONTIG* = '7'

## Further link types may be defined later.
## Bits used in the mode field - values in octal
const
  TSUID* = 0o000000004000
  TSGID* = 0o000000002000
  TSVTX* = 0o000000001000

## File permissions
const
  TUREAD* = 400
  TUWRITE* = 200
  TUEXEC* = 100
  TGREAD* = 40
  TGWRITE* = 20
  TGEXEC* = 10
  TOREAD* = 4
  TOWRITE* = 2
  TOEXEC* = 1
