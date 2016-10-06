###
# Dockerfile for building "dup" under Linux
##
FROM nimlang/nim:0.14.3

RUN apt-get update && apt-get install -y build-essential wget git

# Dup handling
RUN mkdir /dup
ADD ./src /dup/src
ADD dup.nimble /dup/dup.nimble
ADD ./Makefile /dup/Makefile

WORKDIR /dup
RUN nimble -y install
ENV NIM_ENV=release
RUN make release
RUN strip -s build/dup
