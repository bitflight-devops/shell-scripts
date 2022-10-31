#!/bin/bash
MOD_NAME="$(basename "$(cd "$(dirname "${0}")" && pwd -P)")"
echo "${MOD_NAME}"
go mod download
go mod tidy
go build -v .
go run .
