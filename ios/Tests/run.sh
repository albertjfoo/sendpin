#!/bin/sh
#
# Runs the share extension's URL-parsing checks.
#
#     ios/Tests/run.sh
#
# No simulator, no Xcode project, no test target — swiftc compiles the three
# files that matter and runs them. Takes about two seconds.
#
# Run this after touching Destination.swift or Waypoint.swift. Parsing is the
# part that fails quietly: a wrong coordinate still looks like a successful
# send, right up until the Karoo routes you somewhere else.

set -e
cd "$(dirname "$0")/.."

out=$(mktemp -t sendpin-check)
trap 'rm -f "$out"' EXIT

swiftc Tests/main.swift SendPinShare/Destination.swift Shared/Waypoint.swift -o "$out"
"$out"
