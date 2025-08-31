#!/bin/bash

cd "$(dirname "$0")"

echo "Setting up SSH keys for container..."

# Wait for container to be ready
sleep 5

# Setup SSH keys in config directory
docker exec nmssh-test-server mkdir -p /config/.ssh
docker cp ssh-keys/authorized_keys nmssh-test-server:/config/.ssh/authorized_keys
docker exec nmssh-test-server chown -R 1000:1000 /config/.ssh
docker exec nmssh-test-server chmod 700 /config/.ssh
docker exec nmssh-test-server chmod 600 /config/.ssh/authorized_keys

# Setup SSH keys in user home directory  
docker exec nmssh-test-server mkdir -p /home/user/.ssh
docker cp ssh-keys/authorized_keys nmssh-test-server:/home/user/.ssh/authorized_keys
docker exec nmssh-test-server chown -R 1000:1000 /home/user/.ssh
docker exec nmssh-test-server chmod 700 /home/user/.ssh
docker exec nmssh-test-server chmod 600 /home/user/.ssh/authorized_keys

# Ensure user home directory exists and has correct ownership
docker exec nmssh-test-server mkdir -p /home/user
docker exec nmssh-test-server chown -R 1000:1000 /home/user

# Copy and apply SSH daemon configuration
docker cp sshd_config nmssh-test-server:/etc/ssh/sshd_config

# Restart SSH daemon
docker exec nmssh-test-server pkill sshd
sleep 3

echo "SSH keys configured successfully"
