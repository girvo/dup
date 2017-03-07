## A Docker API implementation via Unix sockets

import
  net,
  nre,
  strutils,
  sequtils

type
  ContentState {.pure.} = enum
    Text, Gzip
  BodyState {.pure.} = enum
    Unknown, ContentLength, Chunked
  ParserState {.pure.} = enum
    Headers, Body
  HttpParser = object
    currentState: ParserState
    bodyState: BodyState
    contentState: ContentState

proc newHttpParser(): HttpParser =
  result.bodyState = BodyState.Unknown
  result.currentState = ParserState.Headers
  result.contentState = ContentState.Text

var
  parser: HttpParser = newHttpParser()
const
  dockerSocket = "/var/run/docker.sock"
let
  sock: Socket = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  # handle: SocketHandle = sock.getFd()
# handle.setBlocking(false)

echo "Connecting to socket..."
sock.connectUnix(dockerSocket)
sock.send("GET /v1.26/containers/json HTTP/1.1\nHost: localhost\n\n")
var
  linebuf: TaintedString = ""
  bodybuf: TaintedString = ""
  lines = newSeq[TaintedString]()
  bodylen: int = 0
let
  contentLength = re"^Content\-Length\:\ ?([\d]+)$"
  transferChunked = re"^Transfer-Encoding: chunked$"
# Read headers
while parser.currentState == ParserState.Headers:
  sock.readLine(linebuf)
  if linebuf != "\r\n":
    lines.add(linebuf)

    ### TODO: Move this into a parseHeaders that iterates over the seq instead
    var contentLengthMatch = linebuf.find(contentLength)
    if contentLengthMatch.isSome:
      parser.bodyState = BodyState.ContentLength
      bodylen = parseInt(contentLengthMatch.get().captures[0])
    if linebuf.contains(transferChunked):
      parser.bodyState = BodyState.Chunked
  else:
    parser.currentState = ParserState.Body

# Read body
if parser.bodyState == BodyState.ContentLength:
  bodybuf.setLen(bodylen)
  discard sock.recv(bodybuf, bodylen)
  lines.add(bodybuf)
  echo bodybuf.strip()
elif parser.bodyState == BodyState.Chunked:
  echo "Transfer encoding, chunked!!!"
else:
  echo "Unknown state for HttpParser.bodyState"

# for line in lines: echo "'", line, "'"
