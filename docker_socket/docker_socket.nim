## A Docker API implementation via Unix sockets

import net, pegs, unicode, sequtils
from strutils import strip, parseInt, join, splitLines

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
  Header = tuple[key, value: string]
  Response = object of RootObj
    statusLine*: string
    statusCode*: int
    headers: seq[Header]
    body: string
    bodyLength*: int
  ## Parser types
  ContentState {.pure.} = enum
    Text, Gzip
  BodyState {.pure.} = enum
    Unknown, ContentLength, Chunked
  ParserState {.pure.} = enum
    Headers, Body
  HttpParser = object of RootObj
    currentState: ParserState
    bodyState: BodyState
    contentState: ContentState
    rawHeaders: TaintedString
    curResponse: Response

## Constructors
proc newEmptyResponse(): Response =
  result.statusLine = ""
  result.statusCode = -1
  result.headers = @[]
  result.body = ""
  result.bodyLength = -1

proc newHttpParser(): HttpParser =
  result.bodyState = BodyState.Unknown
  result.currentState = ParserState.Headers
  result.contentState = ContentState.Text
  result.rawHeaders = ""
  result.curResponse = newEmptyResponse()

## Procs and Methods
proc keyEqualTo(header: Header, cmp: string): bool =
  header.key.toLower == cmp.toLower

proc parseStatus(raw: string): tuple[code: int, msg: string] =
  if raw =~ peg"{\d\d\d}\ {.*}":
    result.code = matches[0].parseInt()
    result.msg = matches[1]
  else:
    raise newException(OSError, "Invalid status code?")

method addHeader(self: var Response, header: Header) {.base.} =
  # Adds a header tuple to the internal headers seq
  self.headers.add(header)

method setBody(self: var Response, body: string) {.base.} =
  # Sets the body string value (TODO: It's not always a string!)
  self.body = body

method addRawHeader(self: var HttpParser, line: TaintedString) {.base.} =
  self.rawHeaders.add(line & "\n")

method parseHeaders(self: var HttpParser) {.base.} =
  ## Parses single header lines into proper Header tuples
  for line in splitLines(self.rawHeaders):
    if line =~ httpHeaderPeg:
      self.curResponse.headers.add((key: matches[0], value: matches[1]))
    elif line =~ statusLinePeg:
      let
        parsed = matches[0].parseStatus()
      self.curResponse.statusCode = parsed.code
      self.curResponse.statusLine = line

method readHeaders(self: var HttpParser) {.base.} =
  ## Read the headers to control teh state machine
  for i, header in self.curResponse.headers:
    if header.keyEqualTo("content-length"):
      self.bodyState = BodyState.ContentLength
      self.curResponse.bodyLength = header.value.parseInt()
    elif header.keyEqualTo("transfer-encoding") and header.value == "chunked":
      self.bodyState = BodyState.Chunked

const dockerSocket = "/var/run/docker.sock"
proc request*(uri: string, version: string = "v1.26"): Response =
  let
    sock: Socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  var
    parser: HttpParser = newHttpParser()
    linebuf: TaintedString = ""
    bodybuf: TaintedString = ""
  sock.connectUnix(dockerSocket)
  sock.send("GET /" & version & uri & " HTTP/1.1\nHost: localhost\n\n")

  # Read raw headers into a string
  while parser.currentState == ParserState.Headers:
    sock.readLine(linebuf)
    if linebuf != "\r\n":
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
    echo "Transfer encoding, chunked!!!"
  else:
    echo "Unknown state for HttpParser.bodyState"
  sock.close()
  result = parser.curResponse

## Testing data
var req = request("/containers/json")
echo req.statusCode
echo req.body
