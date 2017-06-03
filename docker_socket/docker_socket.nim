## A Docker API implementation via Unix sockets

import net, pegs, unicode, sequtils, json, jsonob, options, tables
from strutils import strip, parseInt, join, splitLines
from parseutils import parseHex
from curl import nil

## PEGs for parsing headers and status lines
let
  httpHeaderPeg = peg"""
    header <- {key} \s* ':' \s* {value+}
    key <- [A-Za-z0-9_-]*
    value <- \S*\ident*[;\ ]*
  """
  statusLinePeg = peg"i'http/1.'[01] \s+ {.*}"

type
  ## HTTP Response types
  Header* = tuple[key, value: string]
  Response* = object of RootObj
    statusLine*: string
    statusCode*: int
    headers*: seq[Header]
    body*: string
    bodyLength*: int
  ## Parser types
  ContentState* {.pure.} = enum
    Text, Gzip
  BodyState* {.pure.} = enum
    Unknown, ContentLength, Chunked
  ParserState {.pure.} = enum
    Headers, Body
  HttpParser* = object of RootObj
    currentState*: ParserState
    bodyState*: BodyState
    contentState*: ContentState
    rawHeaders*: TaintedString
    curResponse*: Response

## Constructors
proc newEmptyResponse*(): Response =
  result.statusLine = ""
  result.statusCode = -1
  result.headers = @[]
  result.body = ""
  result.bodyLength = -1

proc newHttpParser*(): HttpParser =
  result.bodyState = BodyState.Unknown
  result.currentState = ParserState.Headers
  result.contentState = ContentState.Text
  result.rawHeaders = ""
  result.curResponse = newEmptyResponse()

## Procs and Methods
proc keyEqualTo*(header: Header, cmp: string): bool =
  header.key.toLower == cmp.toLower

proc parseStatus*(raw: string): tuple[code: int, msg: string] =
  if raw =~ peg"{\d\d\d}\ {.*}":
    result.code = matches[0].parseInt()
    result.msg = matches[1]
  else:
    raise newException(OSError, "Invalid status code?")

proc addHeader*(self: var Response, header: Header) =
  # Adds a header tuple to the internal headers seq
  self.headers.add(header)

proc setBody*(self: var Response, body: string) =
  # Sets the body string value (TODO: It's not always a string!)
  self.body = body

proc addRawHeader*(self: var HttpParser, line: TaintedString) =
  self.rawHeaders.add(line & "\n")

proc parseHeaders*(self: var HttpParser) =
  ## Parses single header lines into proper Header tuples
  for line in splitLines(self.rawHeaders):
    if line =~ httpHeaderPeg:
      self.curResponse.headers.add((key: matches[0], value: matches[1]))
    elif line =~ statusLinePeg:
      let
        parsed = matches[0].parseStatus()
      self.curResponse.statusCode = parsed.code
      self.curResponse.statusLine = line

proc readHeaders*(self: var HttpParser) =
  ## Read the headers to control teh state machine
  for i, header in self.curResponse.headers:
    if header.keyEqualTo("content-length"):
      self.bodyState = BodyState.ContentLength
      self.curResponse.bodyLength = header.value.parseInt()
    elif header.keyEqualTo("transfer-encoding") and header.value == "chunked":
      self.bodyState = BodyState.Chunked

const dockerSocket* = "/var/run/docker.sock"
proc request*(uri: string, mthd: string = "GET", version: string = "v1.26"): Response =
  let
    sock: Socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  var
    parser: HttpParser = newHttpParser()
    linebuf: string = ""
    bodybuf: string = ""
  sock.connectUnix(dockerSocket)
  # defer: sock.close()
  sock.send(mthd & " /" & version & uri & " HTTP/1.1\nHost: http\n\n")

  # Read raw headers into a string
  while parser.currentState == ParserState.Headers:
    linebuf = sock.recvLine()
    if linebuf != "\r\L":
      parser.addRawHeader(linebuf)
    else:
      parser.currentState = ParserState.Body

  parser.parseHeaders()
  parser.readHeaders()

  # Read body
  if parser.bodyState == BodyState.ContentLength:
    bodybuf.setLen(parser.curResponse.bodyLength)
    discard sock.recv(bodybuf, parser.curResponse.bodyLength)
    parser.curResponse.body = bodybuf
  elif parser.bodyState == BodyState.Chunked:
    var
      cont = true
      chunkCount = 1
    while cont:
      var chunkLen = 0
      write(stdout, "Chunk: " & $chunkCount & "\n")
      chunkCount += 1
      linebuf = sock.recvLine()
      write(stdout, "Raw: " & $linebuf & "\n")
      if parseHex("0x" & linebuf, chunkLen) != 0:
        if chunkLen != 0:
          write(stdout, $linebuf & "\n")
          write(stdout, $chunkLen & "\n\n")
          bodybuf.setLen(chunkLen)
          if sock.recv(bodybuf, chunkLen) == 0:
            cont = false
            raise newException(IOError, "Hissy fit!")
          parser.curResponse.body &= bodybuf
        else: cont = false
      else:
        cont = false
  else:
    echo "Unknown state for HttpParser.bodyState"
  result = parser.curResponse

type
  Image* = object of RootObj
    Id*: string
    Created*: int
    Containers*: int
    ParentId*: string
    RepoDigests*: Option[seq[string]]
    RepoTags*: Option[seq[string]]
    SharedSize*: int
    Size*: int
    VirtualSize*: int
    Labels*: Option[Table[string, string]]
  Images* = seq[Image]

# Porting this util function
proc not_nil_and_is(root: JsonNode, kind: JsonNodeKind) =
  if root.is_nil:
    assert(false, ("got nil, but expect $#" & $kind))
  if root.kind != kind:
    assert(false, "got " & $root.kind & ", but expect " & $kind)

# Writing our custom handlers for Table-style types
proc to[A, B](root: JsonNode, x: var Table[A, B]) =
  root.not_nil_and_is(JObject) # Check its the right type
  x = initTable[A, B]() # Initalise the table
  for k,v in root.getFields():
    x.add(k, v.str)

proc getImages*(all: bool = false): Images =
  let
    uriFragment = if all: "?all=true" else: ""
    response = request("/images/json" & uriFragment)
  result = response.body.parse_json().to(Images)

type
  Containers* = seq[Container]
  Container* = object of RootObj
    Id*: string
    Names*: seq[string]
    Image*: string
    ImageID*: string
    Command*: string
    Created*: int
    Ports*: seq[string]
    Labels*: Option[Table[string, string]]
    State*: string
    Status*: string
    HostConfig*: HostConfig
    # Mounts*: seq[string]
  HostConfig* = object
    NetworkMode*: string

proc getContainers*(all: bool = false): Containers =
  let
    uriFragment = if all: "?all=true" else: ""
    response = request("/containers/json" & uriFragment)
  result = response.body.parse_json().to(Containers)

type
  ## Version handling
  Version* = object of RootObj
    Version*: string
    Os*: string
    KernelVersion*: string
    GoVersion*: string
    GitCommit*: string
    Arch*: string
    ApiVersion*: string
    MinAPIVersion*: string
    BuildTime*: string
    Experimental*: bool

proc getVersion*(): Version =
  let response = request("/version")
  result = response.body.parse_json().to(Version)

proc getLogs*() =
  let
    # query = "?stdout=true&stderr=true"
    response = request("/containers/rds-web/logs?stdout=true&stderr=true&timestamps=true&follow=false")
  write(stdout, $response.body)
  return
  # echo response.body.parse_json().pretty()


###
# cURL testing...
##
type
  NulString = string
  Buffer = tuple
    data: NulString
    size: int

proc echo(s: NulString) = write(stdout, s)

var buffer: Buffer = (data: newString(0), size: 0)

proc writeMemCbproc(buf: cstring, size: int, nitems: int, outstream: pointer): int =
  let realsize = size * nitems
  buffer.data.setLen(buffer.size + realsize)
  for i in 0..realsize:
    buffer.data[buffer.size + i] = buf[i]
  buffer.size = buffer.size + realsize
  return realsize

when isMainModule:
  # Initialise cURL (ignoring errors for now)
  getLogs()
