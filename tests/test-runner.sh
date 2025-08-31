#!/bin/bash

echo "NMSSH Enhanced Test Runner"
echo "=========================="

cd "$(dirname "$0")"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Stop existing container
docker stop nmssh-test-server 2>/dev/null || true
docker rm nmssh-test-server 2>/dev/null || true

echo "Starting enhanced SSH test server..."
docker run -d --name nmssh-test-server -p 2222:2222 \
    -e PASSWORD_ACCESS=true -e USER_PASSWORD=password -e USER_NAME=user \
    -e SUDO_ACCESS=false \
    -v "$(pwd)/test-data:/var/www/nmssh-tests" \
    -v "$(pwd)/ssh-keys:/config/.ssh" \
    linuxserver/openssh-server

echo "Waiting for SSH server to be ready..."
sleep 10

# Setup SSH keys
echo "Configuring SSH keys..."
./setup-ssh.sh

# Test SSH connection
echo "Testing SSH connection..."
for i in {1..10}; do
    if nc -z 127.0.0.1 2222 2>/dev/null; then
        echo "SSH server is ready on port 2222"
        break
    fi
    echo "Waiting for SSH server... ($i/10)"
    sleep 2
done

if ! nc -z 127.0.0.1 2222 2>/dev/null; then
    echo "SSH server failed to start"
    docker logs nmssh-test-server
    exit 1
fi

# Setup SSH agent for agent tests
eval "$(ssh-agent -s)"
ssh-add ssh-keys/id_rsa 2>/dev/null || echo "SSH agent setup failed (expected for some tests)"

# Run tests with timeout
echo "Running NMSSH tests with 120s timeout..."
cd ..
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64' &
TEST_PID=$!

# Wait for test completion or timeout
(sleep 120; kill -TERM $TEST_PID 2>/dev/null) &
TIMEOUT_PID=$!

wait $TEST_PID 2>/dev/null
TEST_EXIT=$?

# Kill timeout process if tests completed
kill $TIMEOUT_PID 2>/dev/null

if [ $TEST_EXIT -eq 143 ] || [ $TEST_EXIT -eq 15 ]; then
    echo "Tests timed out after 120 seconds"
    TEST_EXIT=124
fi

echo "Stopping SSH test server..."
docker stop nmssh-test-server
docker rm nmssh-test-server

# Kill SSH agent
ssh-agent -k 2>/dev/null || true

exit $TEST_EXIT
