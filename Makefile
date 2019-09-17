BINARY=gserver
CLIENT_BINARY=gclient

VERSION=1.0.0
BUILD=`git rev-parse HEAD`

# ToDo: set verions stuffs in files
# Setup the -ldflags option for go build here, interpolate the variable values
# LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}"


build:
	go build -o test main.go

install:
	go install

clean:
	rm test

.PHONY: build run test install clean
