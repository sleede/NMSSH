#!/bin/bash

echo "NMSSH Test Runner"
echo "================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Use the enhanced test runner from tests directory
cd tests
./test-runner.sh
exit_code=$?

cd ..
exit $exit_code
