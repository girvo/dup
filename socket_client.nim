## This is a temporary example for the new Unix socket support added recently
## Waiting on it to be merged into master, for now we're leveraging it ourselves
import net

let sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)

sock.connectUnix("sock")
sock.send("hello\n")
