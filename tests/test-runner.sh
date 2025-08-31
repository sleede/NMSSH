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
echo "Setting up SSH agent..."
eval "$(ssh-agent -s)"

# Add the passwordless SSH key for agent testing
ssh-add ssh-keys/id_rsa_nopass 2>/dev/null && echo "Added passwordless key to SSH agent"

# Also add the password-protected key for other tests
if [ -f /tmp/ssh_askpass.sh ]; then
    rm -f /tmp/ssh_askpass.sh
fi

cat > /tmp/ssh_askpass.sh << 'EOF'
#!/bin/bash
echo "password"
EOF
chmod +x /tmp/ssh_askpass.sh

DISPLAY=:0 SSH_ASKPASS=/tmp/ssh_askpass.sh ssh-add ssh-keys/id_rsa 2>/dev/null && echo "Added password-protected key to SSH agent"
rm -f /tmp/ssh_askpass.sh

# Export SSH agent variables for the test process
export SSH_AUTH_SOCK
export SSH_AGENT_PID

# Verify SSH agent has the keys
ssh-add -l && echo "SSH agent configured with keys" || echo "SSH agent setup incomplete"

# Run tests with timeout
echo "Running NMSSH tests with 120s timeout..."
cd ..

# Export SSH agent environment for xcodebuild
export SSH_AUTH_SOCK
export SSH_AGENT_PID

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
