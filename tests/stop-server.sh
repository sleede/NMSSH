#!/bin/bash
set -e

echo "Stopping SSH test server..."
docker stop nmssh-test-ssh 2>/dev/null || true
docker rm nmssh-test-ssh 2>/dev/null || true
