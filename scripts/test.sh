#!/bin/bash
# Runs the unit tests with the Command Line Tools. SwiftPM doesn't find the Swift Testing macro plugin without the plugin path.
set -euo pipefail
cd "$(dirname "$0")/.."
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing "$@"
