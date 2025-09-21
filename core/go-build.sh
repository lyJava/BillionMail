#!/bin/sh
# How to use:
# cd /opt/BillionMail
# docker run -d --name p-g-alpine --hostname p-g-alpine --restart=always -v ./core:/opt/core -v ./Dockerfiles/core/repositories:/etc/apk/repositories alpine:3.20 tail -f /dev/null
# docker exec -it p-g-alpine sh
# cd /opt/core
# sh go-build.sh

set -e # Exit immediately when encountering an error
set -x

PLATFORMS=${1:-"all"}

# Validate platform argument
if [ "$PLATFORMS" != "all" ] && [ "$PLATFORMS" != "x86" ] && [ "$PLATFORMS" != "arm" ]; then
  echo "Packaging architecture parameters are incorrect, please enter all, x86, arm"
  echo "Example: sh go-build.sh all"
  exit 1
fi

# Check and install Go (if not exist or version is lower than 1.22)
if ! command -v go >/dev/null 2>&1; then
  echo "Error: Go is not installed, it is being installed automatically..."
  apk update && apk add go file
else
  REQUIRED_MAJOR=1
  REQUIRED_MINOR=22

  GO_VER=$(go version | awk '{print $3}' | sed 's/go//')
  GO_MAJOR=$(echo "$GO_VER" | cut -d. -f1)
  GO_MINOR=$(echo "$GO_VER" | cut -d. -f2)

  if [ "$GO_MAJOR" -lt "$REQUIRED_MAJOR" ] || { [ "$GO_MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$GO_MINOR" -lt "$REQUIRED_MINOR" ]; }; then
    echo "Error: Go version is lower than 1.22, please upgrade manually."
    exit 1
  fi
fi

# Check and install the file (if not exists)
if ! command -v file >/dev/null 2>&1; then
  echo "Warning: file not installed, it is being installed automatically..."
  apk update && apk add file
fi

# Verify installation results
echo "Current environment:"
echo "- Go version: $(go version 2>/dev/null || echo 'Not installed')"
echo "- file version: $(file --version 2>/dev/null || echo 'Not installed')"

#go env -w GOPROXY=https://goproxy.io,direct

# Ensure /opt/core exists
if [ ! -d "/opt/core" ]; then
  echo "/opt/core not found"
  exit 1
fi
cd /opt/core

if [ ! -f "main.go" ]; then
  echo "main.go not found"
  exit 1
fi

go mod tidy

# Build amd64
if [ "$PLATFORMS" = "all" ] || [ "$PLATFORMS" = "x86" ]; then
  echo "Build start amd64"
  rm -f billionmail-amd64

  export GOOS=linux
  export GOARCH=amd64
  go build -ldflags="-s -w" -o billionmail-amd64 main.go
  if [ ! -f "billionmail-amd64" ]; then
    echo "Build amd64 failed"
    exit 1
  fi

  check_file=$(file billionmail-amd64 | grep "x86-64,")
  if [ -z "${check_file}" ]; then
    echo "billionmail-amd64 is not an arm64 file, package failed."
    exit 1
  fi
fi

# Build arm64
if [ "$PLATFORMS" = "all" ] || [ "$PLATFORMS" = "arm" ]; then
  # arm64
  echo "Build start arm64"
  rm -f billionmail-arm64

  export GOOS=linux
  export GOARCH=arm64
  go build -ldflags="-s -w" -o billionmail-arm64 main.go
  if [ ! -f "billionmail-arm64" ]; then
    echo "Build arm64 failed"
    exit 1
  fi

  check_file=$(file billionmail-arm64 | grep -E "ARM|aarch64")
  if [ -z "${check_file}" ]; then
    echo "billionmail-arm64 is not an arm64 file, package failed."
    exit 1
  fi
fi

ls -al billionmail-*
