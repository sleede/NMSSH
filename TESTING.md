# Testing NMSSH

## Prerequisites

1. **Configuration File**: Copy the sample configuration file:
   ```bash
   cp NMSSHTests/Settings/config.sample.yml NMSSHTests/Settings/config.yml
   ```

2. **Edit Configuration**: Update `NMSSHTests/Settings/config.yml` with your SSH server details:
   - Host and port
   - Username and password
   - SSH key paths
   - Test directories (writable and non-writable)

3. **SSH Server**: Ensure you have access to an SSH server for testing

## Architecture Limitations

The tests currently only work on **x86_64 architecture** due to the YAML framework dependency (`NMSSHTests/Settings/lib/YAML.framework`) being compiled only for x86_64. On Apple Silicon Macs, you'll need to run tests under Rosetta.

## Running Tests

### macOS Framework Tests
```bash
# Build framework only (works on all architectures)
xcodebuild build -project NMSSH.xcodeproj -scheme NMSSH

# Run tests (x86_64 only)
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64'
```

### iOS Framework Tests
```bash
# List available schemes
xcodebuild -project NMSSH-iOS.xcodeproj -list

# Build iOS framework
xcodebuild build -project NMSSH-iOS.xcodeproj -scheme "NMSSH Framework"
```

## Test Structure

The test suite includes:
- `NMSSHSessionTests` - SSH session connection and authentication tests
- `NMSSHChannelTests` - SSH channel and command execution tests  
- `NMSFTPTests` - SFTP file transfer tests
- `NMSFTPFileTests` - SFTP file operations tests
- `NMSSHConfigTests` - SSH configuration parsing tests

## Known Issues

1. **Architecture Dependency**: Tests require x86_64 due to YAML framework
2. **Configuration Required**: Tests will fail without proper `config.yml` setup
3. **Server Dependency**: Tests require a live SSH server matching the configuration

## Alternative Testing

For development on Apple Silicon without x86_64 testing:
- Build the framework to verify compilation: `xcodebuild build -project NMSSH.xcodeproj -scheme NMSSH`
- Use the Examples directory for manual testing
- Consider updating the YAML framework to support arm64 for full test compatibility
