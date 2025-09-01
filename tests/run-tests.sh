#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Starting SSH test server..."
docker run -d --name nmssh-test-ssh \
  -p 2222:22 \
  -e SSH_USERS=user:1000:1000 \
  -e SSH_ENABLE_PASSWORD_AUTH=true \
  -v "$(pwd)/ssh-keys/authorized_keys:/home/user/.ssh/authorized_keys:ro" \
  -v "$(pwd)/test-data:/tmp/test-data:ro" \
  panubo/sshd:1.1.0 \
  sh -c "echo 'user:password' | chpasswd && mkdir -p /var/www/nmssh-tests/valid/listing /var/www/nmssh-tests/invalid && cp -r /tmp/test-data/* /var/www/nmssh-tests/ && echo 'test content' > /var/www/nmssh-tests/valid/listing/d.txt && echo 'test content' > /var/www/nmssh-tests/valid/listing/e.txt && echo 'test content' > /var/www/nmssh-tests/valid/listing/f.txt && mkdir -p /var/www/nmssh-tests/valid/listing/a /var/www/nmssh-tests/valid/listing/b /var/www/nmssh-tests/valid/listing/c && chown -R user:user /var/www/nmssh-tests && chmod -R 755 /var/www/nmssh-tests/valid && chmod -R 555 /var/www/nmssh-tests/invalid && /usr/sbin/sshd -D"

echo "Waiting for SSH server..."
sleep 5

echo "Running all tests..."
cd ..
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64'

echo "Stopping SSH test server..."
docker stop nmssh-test-ssh
docker rm nmssh-test-ssh
