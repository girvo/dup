###
# Dockerfile for building "dup" under Linux
##
FROM ubuntu:16.04

RUN apt-get update && apt-get install -y build-essential wget git

# Nim
WORKDIR /opt
RUN wget http://nim-lang.org/download/nim-0.13.0.tar.xz
RUN tar xvf nim-0.13.0.tar.xz
WORKDIR /opt/nim-0.13.0
RUN sh build.sh
ENV PATH /opt/nim-0.13.0/bin:$PATH

# Nimble
WORKDIR /opt
RUN git clone https://github.com/nim-lang/nimble.git
WORKDIR /opt/nimble
RUN nim -d:release c -r src/nimble install
ENV PATH /root/.nimble/bin:$PATH

# Dup handling
RUN mkdir /dup
ADD ./src /dup/src
ADD dup.nimble /dup/dup.nimble
ADD ./Makefile /dup/Makefile

WORKDIR /dup
RUN nimble -y install
RUN make
