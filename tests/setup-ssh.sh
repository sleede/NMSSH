#!/bin/bash

cd "$(dirname "$0")"

echo "Setting up SSH keys for container..."

# Wait for container to be ready
sleep 5

# Copy SSH keys and setup proper permissions
docker exec nmssh-test-server mkdir -p /config/.ssh
docker cp ssh-keys/authorized_keys nmssh-test-server:/config/.ssh/authorized_keys
docker exec nmssh-test-server chown -R 1000:1000 /config/.ssh
docker exec nmssh-test-server chmod 700 /config/.ssh
docker exec nmssh-test-server chmod 600 /config/.ssh/authorized_keys

# Also setup for the user directory
docker exec nmssh-test-server mkdir -p /home/user/.ssh
docker cp ssh-keys/authorized_keys nmssh-test-server:/home/user/.ssh/authorized_keys
docker exec nmssh-test-server chown -R 1000:1000 /home/user/.ssh
docker exec nmssh-test-server chmod 700 /home/user/.ssh
docker exec nmssh-test-server chmod 600 /home/user/.ssh/authorized_keys

# Restart SSH service
docker exec nmssh-test-server pkill sshd
sleep 3

echo "SSH keys configured successfully"
