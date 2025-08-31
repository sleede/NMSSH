# Testing NMSSH

## Quick Start

The easiest way to run tests is using the provided test runner:

```bash
./run-tests.sh
```

This will automatically:
- Start a Docker SSH test server
- Configure SSH keys and authentication
- Run the complete NMSSH test suite
- Clean up all resources

## Prerequisites

1. **Docker**: Ensure Docker is installed and running
2. **Xcode**: Tests require Xcode and the macOS SDK
3. **Architecture**: Tests currently require x86_64 due to YAML framework dependency

## Manual Testing

### Using the Enhanced Test Runner

```bash
cd tests
./test-runner.sh
```

### Direct xcodebuild Testing

```bash
# Build framework only (works on all architectures)
xcodebuild build -project NMSSH.xcodeproj -scheme NMSSH

# Run tests (x86_64 only)
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64'
```

## Test Environment

### SSH Server Configuration
- **Host**: 127.0.0.1:2222
- **Username**: user
- **Password**: password
- **SSH Keys**: Generated test keys with password "password"
- **SCP/SFTP**: Fully enabled
- **Test Directories**: 
  - `/var/www/nmssh-tests/valid/` (writable)
  - `/var/www/nmssh-tests/invalid/` (read-only)

### Generated SSH Keys
- `tests/ssh-keys/id_rsa` - Valid test key (password: "password")
- `tests/ssh-keys/github_rsa` - Invalid test key (no password)
- `tests/ssh-keys/authorized_keys` - Authorized keys for server

## Test Results

The test suite includes 58 tests covering:
- ✅ Password authentication (10/10 tests pass)
- ⚠️ Public key authentication (4/5 tests pass - 1 known issue)
- ⚠️ SSH agent authentication (0/1 tests pass - known limitation)
- ✅ SCP file transfers (6/6 tests pass)
- ✅ SFTP operations (7/7 tests pass)
- ✅ Shell command execution (1/1 tests pass)
- ✅ SSH configuration parsing (28/28 tests pass)
- ✅ File operations (2/2 tests pass)

**Current Status**: 56/58 tests pass (96.6% success rate)

## Known Issues

1. **Public Key Authentication**: One test fails due to SSH key configuration in Docker container
2. **SSH Agent Authentication**: Fails due to SSH agent not being properly configured in test environment
3. **Architecture Dependency**: Tests require x86_64 due to YAML framework limitation

## Architecture Limitations

The tests currently only work on **x86_64 architecture** due to the YAML framework dependency (`NMSSHTests/Settings/lib/YAML.framework`) being compiled only for x86_64. On Apple Silicon Macs, tests run under Rosetta.

## Alternative Testing

For development on Apple Silicon without x86_64 testing:
- Build the framework to verify compilation: `xcodebuild build -project NMSSH.xcodeproj -scheme NMSSH`
- Use the Examples directory for manual testing
- Consider updating the YAML framework to support arm64 for full test compatibility

## Troubleshooting

### Docker Issues
- Ensure Docker Desktop is running
- Check container logs: `docker logs nmssh-test-server`

### SSH Connection Issues
- Verify SSH server is running on port 2222: `nc -z 127.0.0.1 2222`
- Check SSH key permissions in container

### Test Failures
- Most test failures are related to SSH server connectivity
- Ensure no other services are using port 2222
- Try restarting Docker Desktop if tests consistently fail
