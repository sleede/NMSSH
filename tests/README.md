# NMSSH Tests

## Running Tests

From the project root directory:

```bash
./tests/run-tests.sh
```

Or run tests directly with Xcode:

```bash
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH
```

## What the test script does

1. Starts SSH test server with Docker
2. Runs all NMSSH tests (56 tests total)
3. Stops the test server

## Requirements

- Docker
- Xcode
- SSH keys are automatically set up by the test script

## Test Results

- **56/56 tests passing** (100% success rate)
- All authentication methods tested (password and public key)
- SSH handshake compatibility with modern servers
- SFTP, SCP, and channel operations tested
