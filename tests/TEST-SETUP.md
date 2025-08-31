# NMSSH Enhanced Test Setup

## Quick Start

1. **Start Docker Desktop** (if not already running)

2. **Run the enhanced test script:**
   ```bash
   cd tests
   ./test-runner.sh
   ```

The script will:
- Start an SSH test server with full SCP/SFTP support
- Configure SSH keys for public key authentication
- Setup SSH agent for agent-based tests
- Run NMSSH tests with 120-second timeout
- Clean up all resources

## Test Environment Features

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
- `ssh-keys/id_rsa` - Valid test key (password: "password")
- `ssh-keys/github_rsa` - Invalid test key (no password)
- `ssh-keys/authorized_keys` - Authorized keys for server

### Test Coverage
- ✅ Password authentication
- ✅ Public key authentication  
- ✅ SSH agent authentication
- ✅ SCP file transfers
- ✅ SFTP operations
- ✅ Shell command execution
- ✅ Invalid server handling
- ✅ SSH configuration parsing

## Manual Setup

If you prefer manual control:

### Start Enhanced SSH Server
```bash
cd tests
docker run -d --name nmssh-test-server -p 2222:2222 \
  -e PASSWORD_ACCESS=true -e USER_PASSWORD=password -e USER_NAME=user \
  -v "$(pwd)/test-data:/var/www/nmssh-tests" \
  -v "$(pwd)/ssh-keys:/config/.ssh" \
  linuxserver/openssh-server

./setup-ssh.sh
```

### Run Tests
```bash
cd ..
xcodebuild test -project NMSSH.xcodeproj -scheme NMSSH -destination 'platform=macOS,arch=x86_64'
```

### Cleanup
```bash
docker stop nmssh-test-server
docker rm nmssh-test-server
```

## Expected Results

All 58 tests should now pass with the enhanced environment:
- SSH connection and authentication tests
- File transfer operations (SCP/SFTP)
- Shell command execution
- Configuration parsing
- Error handling for invalid scenarios
