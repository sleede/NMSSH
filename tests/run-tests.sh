#!/bin/bash
set -e

cd "$(dirname "$0")"

# Start the SSH test server
./start-server.sh

# Run the tests
echo "Running all tests..."
cd ..
if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 300 xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH
else
    xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH
fi

# Stop the SSH test server
cd tests
./stop-server.sh
