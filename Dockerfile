###
# Dockerfile for building "dup" under Linux
##
FROM coopernurse/docker-nim:latest

ADD ./src /src
ADD dup.nimble /dup.nimble
ADD ./Makefile /Makefile

RUN apk update
RUN apk add make

WORKDIR /
RUN nimble -y install
