## TAR file implementation in pure Nim

import os, osproc, pegs, streams, strutils

type
  ## Different types, regular Tar or Star
  TarType {.pure.} = enum
    Tar, UStar
  ## Possible values for the typeflag
  FileTypeFlag* {.pure.} = enum
    ARegular = '\0',  # regular file
    Regular = '0',    # regular file
    Link = '1',       # link
    Symlink = '2',    # symlink
    Char = '3',       # character special
    Block = '4',      # block special
    Directory = '5',  # directory
    Fifo = '6',       # FIFO special
    Contiguous = '7', # reserved
    ExtGlobal = 'g'   # Global extended header
    ExtNext = 'x',    # Extended header for next file in archive
  ## Descriptor for a single file hole
  Sparse* {.packed.} = object
    offset: array[12, char]
    numbytes: array[12, char]
  ## 500-ish byte header for each file in the archive
  TarHeader* {.packed.} = object of RootObj
    name: array[100, char]
    mode: array[8, char]
    uid: array[8, char]
    gid: array[8, char]
    size: array[12, char]
    mtime: array[12, char]
    chksum: array[8, char]
    typeflag: FileTypeFlag
    linkname: array[100, char]
    magic: array[6, char]
    version: array[2, char]
    uname: array[32, char]
    gname: array[32, char]
    devmajor: array[8, char]
    devminor: array[8, char]
    case kind: TarType
    of TarType.Tar:
      tprefix: array[155, char]
    of TarType.UStar:
      uprefix: array[131, char]
      atime: array[12, char]
      ctime: array[12, char]
  ## Wrapper around file-streams, including meta-data
  FileHandle* = object of RootObj
    filename*: string
    stream*: FileStream
    size*: int64

proc newFileHandle(fname: string, s: FileStream, size: int64): FileHandle =
  ## FileHandle constructor
  result = FileHandle(filename: fname, stream: s, size: size)

proc createHandleFromFilename*(fname: string): FileHandle =
  ## Public proc to create handle for a given filename
  let stream = newFileStream(fname, fmRead)
  let size = getFileSize(fname)
  result = newFileHandle(fname, stream, size)

proc allocateBuffer*(files: seq[FileHandle]) = discard

proc paddingSize*(file: FileHandle): int64 =
  ## Calculates padding size needed for a given file handle
  result = file.size mod 512

proc listFilesForPath*(path: string): any =
  return "Hello"

when isMainModule:
  echo "*".repeat(80)
  echo "TAR whole-module integration tests..."
  echo "*".repeat(80) & "\n"

  ## Constants
  const folderName = "./.tmp"
  const fileName = folderName & "/test.txt"
  const fileData = "Hello, World!\n".repeat(4)
  const tarFilename = "./test.tar"

  ## Setup
  echo "Creating directory for tests..."
  createDir(folderName)
  echo "Creating file..."
  writeFile(fileName, fileData)

  ## TAR creation...
  echo "Creating TAR file from test directory..."

  ## Removal and cleanup
  echo "Removing test directory..."
  removeDir(folderName)
  defer:
    echo "Cleaning up..."
    removeFile(tarFilename)
    removeDir(folderName)
    echo "Complete!"
    echo "*".repeat(80)

  ## TAR extraction (via the "tar" command, we're not extracting in this lib)
  echo "Extracting TAR file into current directory..."
  assert(execCmd("tar xvf ./test.tar") == 0,
    "Exit code for TAR should be zero")

  ## Read file back
  let f = readFile(fileName)
  assert(f == fileData,
    "Our extracted file should have the same data")
