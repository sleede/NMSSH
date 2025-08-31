#!/bin/bash

# Start SSH server
echo "Starting SSH test server..."
docker-compose up -d

# Wait for server to be ready
echo "Waiting for SSH server to start..."
sleep 5

# Function to run tests with timeout
run_tests_with_timeout() {
    local timeout_duration=60
    local test_cmd="xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64'"
    
    echo "Running tests with ${timeout_duration}s timeout..."
    
    # Use perl as timeout alternative on macOS
    perl -e "alarm $timeout_duration; exec @ARGV" $test_cmd &
    local test_pid=$!
    
    wait $test_pid 2>/dev/null
    local exit_code=$?
    
    if [ $exit_code -eq 142 ]; then
        echo "Tests timed out after ${timeout_duration} seconds"
        return 1
    fi
    
    return $exit_code
}

# Run the tests
run_tests_with_timeout
test_result=$?

# Cleanup
echo "Stopping SSH test server..."
docker-compose down

exit $test_result
