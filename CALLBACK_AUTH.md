# NMSSH Callback Authentication Documentation

## Function Signature

```objc
- (BOOL)authenticateByInMemoryPublicKey:(NSData *)publicKey 
                           signCallback:(int(^)(NSData *data, NSData **signature))signCallback;
```

## Arguments

### publicKey (NSData)

The `publicKey` parameter must contain the SSH wire format public key blob, **not** the PEM or OpenSSH text format.

#### For RSA Keys:
- Extract base64 portion from OpenSSH public key file (`ssh-rsa AAAAB3NzaC1yc2E...`)
- Decode base64 to get SSH wire format blob
- For RSA-SHA2-256, modify the algorithm identifier in the blob from "ssh-rsa" to "rsa-sha2-256"

#### For ECDSA P-256 Keys:
- Extract base64 portion from OpenSSH public key file (`ecdsa-sha2-nistp256 AAAAE2VjZHNh...`)
- Decode base64 to get SSH wire format blob
- Contains: `[4 bytes length]["ecdsa-sha2-nistp256"][4 bytes length]["nistp256"][4 bytes length][65 bytes Q point]`

#### For Ed25519 Keys:
- Extract base64 portion from OpenSSH public key file (`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...`)
- Decode base64 to get SSH wire format blob
- Contains: `[4 bytes length]["ssh-ed25519"][4 bytes length][32 bytes public key]`

### signCallback Block

```objc
int(^)(NSData *data, NSData **signature)
```

#### Input Parameter: `data`
- Raw bytes to be signed (challenge data from SSH server)
- No additional framing or hashing required - this is the exact data to sign

#### Output Parameter: `signature`
- Must be set to point to an NSData containing the signature
- **Return format depends on key type:**

##### RSA Signatures:
- Raw PKCS#1 v1.5 signature bytes (no additional framing)
- Use SHA-1 for "ssh-rsa" algorithm
- Use SHA-256 for "rsa-sha2-256" algorithm
- Length matches key size (256 bytes for RSA-2048, 512 bytes for RSA-4096)

##### ECDSA P-256 Signatures:
- SSH wire format: `[4 bytes 0x00000021][1 byte 0x00][32 bytes r][4 bytes 0x00000021][1 byte 0x00][32 bytes s]`
- Convert from ASN.1 DER format by extracting r and s components
- Each component must be exactly 32 bytes (pad or strip leading zeros as needed)

##### Ed25519 Signatures:
- Raw 64-byte signature (no additional framing)
- Direct output from Ed25519 signing operation

#### Return Value:
- `0` on success
- `-1` on failure

## Example Usage

### RSA with SHA-256
```objc
int(^signCallback)(NSData *, NSData **) = ^int(NSData *data, NSData **signature) {
    // Create SecKey from DER private key data
    SecKeyRef privateKey = SecKeyCreateWithData(privateKeyDER, keyAttrs, &error);
    
    // Sign with SHA-256
    CFDataRef signatureData = SecKeyCreateSignature(privateKey, 
                                                   kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                                   (__bridge CFDataRef)data, 
                                                   &error);
    
    *signature = (__bridge_transfer NSData *)signatureData;
    return signatureData ? 0 : -1;
};
```

### ECDSA P-256
```objc
int(^signCallback)(NSData *, NSData **) = ^int(NSData *data, NSData **signature) {
    // Sign with SecKey (returns ASN.1 DER format)
    CFDataRef asn1Signature = SecKeyCreateSignature(privateKey, 
                                                   kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                   (__bridge CFDataRef)data, 
                                                   &error);
    
    // Convert ASN.1 to SSH wire format
    NSData *sshSignature = [self convertASN1SignatureToSSH:(__bridge NSData *)asn1Signature];
    
    *signature = sshSignature;
    return sshSignature ? 0 : -1;
};
```

### Ed25519
```objc
int(^signCallback)(NSData *, NSData **) = ^int(NSData *data, NSData **signature) {
    // Use CryptoKit or similar Ed25519 implementation
    NSData *sig = [Ed25519Bridge signWithData:data with:cryptoKitPrivateKey];
    
    *signature = sig;
    return sig ? 0 : -1;
};
```

## Key Points

1. **No double hashing**: The `data` parameter is already the final bytes to sign
2. **Algorithm matching**: Public key algorithm identifier must match signing algorithm
3. **Exact format**: Signature format must match SSH protocol expectations for each key type
4. **Error handling**: Return -1 on any failure, 0 on success
5. **Memory management**: The signature NSData will be retained by the framework
