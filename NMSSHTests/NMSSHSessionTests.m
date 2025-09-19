#import "NMSSHSessionTests.h"
#import "NMSSHConfig.h"
#import "NMSSHHostConfig.h"
#import "ConfigHelper.h"

#import <NMSSH/NMSSH.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

@interface NMSSHSessionTests () {
    NSDictionary *validPasswordProtectedServer;
    NSDictionary *validPublicKeyProtectedServer;
    NSDictionary *validAgentServer;
    NSDictionary *invalidServer;

    NMSSHSession *session;
}
@end

@implementation NMSSHSessionTests

// -----------------------------------------------------------------------------
// TEST SETUP
// -----------------------------------------------------------------------------

- (void)setUp {
    validPasswordProtectedServer = [ConfigHelper valueForKey:
                                    @"valid_password_protected_server"];
    validPublicKeyProtectedServer = [ConfigHelper valueForKey:
                                     @"valid_public_key_protected_server"];
    invalidServer = [ConfigHelper valueForKey:@"invalid_server"];
    validAgentServer = [ConfigHelper valueForKey:@"valid_agent_server"];
}

- (void)tearDown {
    if (session) {
        [session disconnect];
        session = nil;
    }
}

// -----------------------------------------------------------------------------
// CONNECTION TESTS
// -----------------------------------------------------------------------------

- (void)testConnectionToValidServerWorks {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];

    XCTAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a valid server does not throw exception");

    XCTAssertTrue([session isConnected],
                 @"Connection to valid server should work");
}

- (void)testConnectionToInvalidServerFails {
    NSString *host = [invalidServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];

    XCTAssertNoThrow(session = [NMSSHSession connectToHost:host
                                             withUsername:username],
                    @"Connecting to a invalid server does not throw exception");

    XCTAssertFalse([session isConnected],
                 @"Connection to invalid server should not work");
}

// -----------------------------------------------------------------------------
// AUTHENTICATION TESTS
// -----------------------------------------------------------------------------

- (void)testPasswordAuthenticationWithValidPasswordWorks {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];
    NSString *password = [validPasswordProtectedServer
                               objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with valid password doesn't throw"
                    @"exception");

    XCTAssertTrue([session isAuthorized],
                 @"Authentication with valid password should work");
}

- (void)testPasswordAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer
                               objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid password doesn't throw"
                    @"exception");

    XCTAssertFalse([session isAuthorized],
                 @"Authentication with invalid password should not work");
}

- (void)testPasswordAuthenticationWithInvalidUserFails {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];
    NSString *password = [invalidServer objectForKey:@"password"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPassword:password],
                    @"Authentication with invalid username/password doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
                  @"Authentication with invalid username/password should not"
                  @"work");
}

- (void)testPublicKeyAuthenticationWithValidKeyWorks {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];
    id passwordObj = [validPublicKeyProtectedServer objectForKey:@"password"];
    NSString *password = ([passwordObj isKindOfClass:[NSNull class]]) ? nil : passwordObj;

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Authentication with valid public key doesn't throw"
                    @"exception");

    XCTAssertTrue([session isAuthorized],
                  @"Authentication with valid public key should work");
}

- (void)testPublicKeyAuthenticationWithInvalidPasswordFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"password_protected_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Public key authentication with invalid password doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
                 @"Public key authentication with invalid password should not"
                 @"work");
}


- (void)testPublicKeyAuthenticationWithInvalidKeyFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"invalid_public_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Authentication with invalid public key doesn't throw"
                    @"exception");

    XCTAssertFalse([session isAuthorized],
                 @"Authentication with invalid public key should not work");
}

- (void)testPublicKeyAuthenticationWithInvalidUserFails {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [invalidServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer
                           objectForKey:@"valid_public_key"];
    id passwordObj = [validPublicKeyProtectedServer objectForKey:@"password"];
    NSString *password = ([passwordObj isKindOfClass:[NSNull class]]) ? nil : passwordObj;

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:password],
                    @"Public key authentication with invalid user doesn't"
                    @"throw exception");

    XCTAssertFalse([session isAuthorized],
                  @"Public key authentication with invalid user should not work");
}



// -----------------------------------------------------------------------------
// CONFIG TESTS
// -----------------------------------------------------------------------------

// Tests synthesis that uses some defaults, some global, and some local values,
// and merges identity files.
- (void)testConfigSynthesisFromChain {
    NMSSHConfig *globalConfig = [[NMSSHConfig alloc] initWithString:
                                    @"Host host\n"
                                    @"    Hostname globalHostname\n"
                                    @"    Port 9999\n"
                                    @"    IdentityFile idFile1\n"
                                    @"    IdentityFile idFile2"];
    NMSSHConfig *userConfig = [[NMSSHConfig alloc] initWithString:
                                  @"Host host\n"
                                  @"    Hostname localHostname\n"
                                  @"    IdentityFile idFile2\n"
                                  @"    IdentityFile idFile3"];
    NSArray *configChain = @[ userConfig, globalConfig ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"localHostname",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @9999,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"defaultUsername",
                          @"User not properly synthesized");
    NSArray *expected = @[ @"idFile2", @"idFile3", @"idFile1" ];
    XCTAssertEqualObjects(session.hostConfig.identityFiles, expected,
                          @"Identity files not properly synthesized");
}

// Tests that all default values can appear in the synthesized config.
- (void)testConfigSynthesisInheritsDefaults {
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:
                              @"Host nonMatchingHost\n"
                              @"    Hostname badHostname\n"
                              @"    Port 9999\n"
                              @"    User badUser\n"
                              @"    IdentityFile badIdFile\n"];
    NSArray *configChain = @[ config ];
    session = [[NMSSHSession alloc] initWithHost:@"goodHost"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"goodUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"goodHost",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @22,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"goodUsername",
                          @"User not properly synthesized");
    NSArray *expected = @[ ];
    XCTAssertEqualObjects(session.hostConfig.identityFiles, expected,
                          @"Identity files not properly synthesized");
}

// Tests that all values respect the priority hierarchy of the config chain.
- (void)testConfigSynthesisRespectsPriority {
    NMSSHConfig *globalConfig = [[NMSSHConfig alloc] initWithString:
                                    @"Host host\n"
                                    @"    Hostname globalHostname\n"
                                    @"    Port 9999\n"
                                    @"    User globalUser"];
    NMSSHConfig *userConfig = [[NMSSHConfig alloc] initWithString:
                                  @"Host host\n"
                                  @"    Hostname localHostname\n"
                                  @"    Port 8888\n"
                                  @"    User localUser"];
    NSArray *configChain = @[ userConfig, globalConfig ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.hostConfig.hostname, @"localHostname",
                          @"Hostname not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.port, @8888,
                          @"Port not properly synthesized");
    XCTAssertEqualObjects(session.hostConfig.user, @"localUser",
                          @"User not properly synthesized");
}

// Tests that values from the config are used in creating the session.
- (void)testConfigIsUsed {
    NMSSHConfig *config = [[NMSSHConfig alloc] initWithString:
                           @"Host host\n"
                           @"    Hostname configHostname\n"
                           @"    Port 9999\n"
                           @"    User configUser\n"];
    NSArray *configChain = @[ config ];
    session = [[NMSSHSession alloc] initWithHost:@"host"
                                         configs:configChain
                                 withDefaultPort:22
                                 defaultUsername:@"defaultUsername"];
    
    XCTAssertEqualObjects(session.host, @"configHostname",
                          @"Hostname from config not used");
    XCTAssertEqualObjects(session.port, @9999,
                          @"Port from config not used");
    XCTAssertEqualObjects(session.username, @"configUser",
                          @"User from config not used");
}

- (NSData *)convertPEMToDER:(NSData *)pemData {
    NSString *pemString = [[NSString alloc] initWithData:pemData encoding:NSUTF8StringEncoding];
    if (!pemString) return nil;
    
    // Remove PEM headers and footers
    NSString *base64String = [pemString stringByReplacingOccurrencesOfString:@"-----BEGIN RSA PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-----END RSA PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-----BEGIN PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-----END PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-----BEGIN EC PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-----END EC PRIVATE KEY-----" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    base64String = [base64String stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return [[NSData alloc] initWithBase64EncodedString:base64String options:0];
}

- (NSData *)extractScalarFromPKCS8:(NSString *)path {
    NSString *pem = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    pem = [pem stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    pem = [pem stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    pem = [pem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSRange start = [pem rangeOfString:@"-----BEGIN PRIVATE KEY-----"];
    NSRange end   = [pem rangeOfString:@"-----END PRIVATE KEY-----"];
    NSString *b64str = [pem substringWithRange:NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start))];
    b64str = [[b64str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    NSData *der = [[NSData alloc] initWithBase64EncodedString:b64str options:0];

    return [der subdataWithRange:NSMakeRange(der.length-32,32)];
}

- (NSData *)parseOpenSSHPub:(NSString *)path {
    NSString *line = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [line componentsSeparatedByString:@" "];
    NSData *blob = [[NSData alloc] initWithBase64EncodedString:parts[1] options:0];

    const uint8_t *p = (const uint8_t*)blob.bytes; size_t len = blob.length;
    uint32_t l1 = ntohl(*(uint32_t*)p); p+=4; len-=4; p+=l1; len-=l1;
    uint32_t l2 = ntohl(*(uint32_t*)p); p+=4; len-=4; p+=l2; len-=l2;
    uint32_t qlen = ntohl(*(uint32_t*)p); p+=4; len-=4;
    return [NSData dataWithBytes:p length:qlen];
}

- (NSArray<NSData *> *)parseECDSASignatureStrict:(NSData *)asn1Signature {
    const uint8_t *bytes = (const uint8_t *)asn1Signature.bytes;
    NSUInteger length = asn1Signature.length;
    NSUInteger pos = 0;

    if (pos >= length || bytes[pos++] != 0x30) return nil; // SEQUENCE

    // Read sequence length
    if (pos >= length) return nil;
    NSUInteger seqLen = bytes[pos++];
    if (seqLen & 0x80) {
        NSUInteger lenBytes = seqLen & 0x7F;
        seqLen = 0;
        for (NSUInteger i = 0; i < lenBytes; i++) {
            if (pos >= length) return nil;
            seqLen = (seqLen << 8) | bytes[pos++];
        }
    }
    if (pos + seqLen != length) return nil; // sanity check

    // Read r
    if (pos >= length || bytes[pos++] != 0x02) return nil;
    if (pos >= length) return nil;
    NSUInteger rLen = bytes[pos++];
    if (rLen & 0x80) return nil; // multi-byte length not expected for P-256
    if (pos + rLen > length) return nil;
    NSData *rData = [NSData dataWithBytes:&bytes[pos] length:rLen];
    pos += rLen;

    // Strip optional leading zero
    if (rData.length == 33 && ((uint8_t *)rData.bytes)[0] == 0x00) {
        rData = [rData subdataWithRange:NSMakeRange(1, 32)];
    }
    if (rData.length != 32) return nil; // must be exactly 32 bytes

    // Read s
    if (pos >= length || bytes[pos++] != 0x02) return nil;
    if (pos >= length) return nil;
    NSUInteger sLen = bytes[pos++];
    if (sLen & 0x80) return nil;
    if (pos + sLen > length) return nil;
    NSData *sData = [NSData dataWithBytes:&bytes[pos] length:sLen];

    // Strip optional leading zero
    if (sData.length == 33 && ((uint8_t *)sData.bytes)[0] == 0x00) {
        sData = [sData subdataWithRange:NSMakeRange(1, 32)];
    }
    if (sData.length != 32) return nil; // must be exactly 32 bytes

    return @[rData, sData];
}

- (NSData *)convertASN1SignatureToSSH:(NSData *)asn1Signature {
  NSArray *array = [self parseECDSASignatureStrict:asn1Signature];
  NSData *rData = array[0];
  NSData *sData = array[1];
  [self logHex:@"rData:" data:rData.bytes len:rData.length];
  [self logHex:@"sData:" data:sData.bytes len:sData.length];

  NSMutableData *result = [NSMutableData data];
  [result appendBytes:"\x00\x00\x00\x21\x00" length:5];
  [result appendData:rData];
  [result appendBytes:"\x00\x00\x00\x21\x00" length:5];
  [result appendData:sData];

  [self logHex:@"result:" data:result.bytes len:result.length];
  return result;
}

- (void)testPublicKeyAuthenticationWithSignCallbackWorks {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKeyPath = [validPublicKeyProtectedServer objectForKey:@"valid_public_key"];
    NSString *privateKeyPath = [publicKeyPath stringByDeletingPathExtension];
    
    // Read public key file and extract base64 part
    NSString *publicKeyString = [NSString stringWithContentsOfFile:publicKeyPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(publicKeyString, @"Should be able to read public key file");
    
    // Extract base64 part from "ssh-rsa AAAAB3... comment"
    NSArray *parts = [publicKeyString componentsSeparatedByString:@" "];
    XCTAssertTrue(parts.count >= 2, @"Public key should have at least 2 parts");
    NSString *base64Key = parts[1];
    NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    XCTAssertNotNil(publicKeyData, @"Should be able to decode base64 public key");
    
    // Read private key data and convert PEM to DER
    NSData *privateKeyPEM = [NSData dataWithContentsOfFile:privateKeyPath];
    XCTAssertNotNil(privateKeyPEM, @"Should be able to read private key file");
    NSData *privateKeyDER = [self convertPEMToDER:privateKeyPEM];
    XCTAssertNotNil(privateKeyDER, @"Should be able to convert PEM to DER");
    
    session = [NMSSHSession connectToHost:host withUsername:username];
    XCTAssertTrue([session isConnected], @"Should connect to test server");
    
    // Create signing callback using SecKeyCreateSignature
    int(^signCallback)(NSData *, NSData **) = ^int(NSData *data, NSData **signature) {
        @try {
            // Create SecKey from DER data
            NSDictionary *keyAttrs = @{
                (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate
            };
            
            CFErrorRef error = NULL;
            SecKeyRef privateKey = SecKeyCreateWithData((__bridge CFDataRef)privateKeyDER, 
                                                       (__bridge CFDictionaryRef)keyAttrs, 
                                                       &error);
            if (!privateKey) {
                if (error) CFRelease(error);
                return -1;
            }
            
            // Sign with SHA1 (SSH default for RSA)
            CFDataRef signatureData = SecKeyCreateSignature(privateKey, 
                                                           kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1,
                                                           (__bridge CFDataRef)data, 
                                                           &error);
            CFRelease(privateKey);
            
            if (!signatureData) {
                if (error) CFRelease(error);
                return -1;
            }
            
            *signature = (__bridge_transfer NSData *)signatureData;
            return 0;
            
        } @catch (NSException *exception) {
            return -1;
        }
    };
    
    XCTAssertNoThrow([session authenticateByInMemoryPublicKey:publicKeyData
                                                 signCallback:signCallback],
                    @"Authentication with sign callback should not throw");
    
    BOOL isAuthorized = [session isAuthorized];
    XCTAssertTrue(isAuthorized, @"Authentication with real RSA signature should work");

    NMSSHChannel *channel = [[NMSSHChannel alloc] initWithSession:session];

    NSError *error = nil;
    XCTAssertNoThrow([channel execute:[validPasswordProtectedServer objectForKey:@"execute_command"]
                               error:&error],
                    @"SignCallback: Execution should not throw an exception");

    XCTAssertTrue(error == nil, @"Signcallback: Exec after sign with real RSA signature should work");

    NSLog(@"SignCallback: %@", [channel lastResponse]);

    XCTAssertEqualObjects([channel lastResponse],
                         [validPasswordProtectedServer objectForKey:@"execute_expected_response"],
                         @"SignCallback: Execution returns the expected response");
}

// -----------------------------------------------------------------------------
// P256 ECDSA KEY TESTS
// -----------------------------------------------------------------------------

- (void)testP256ECDSAPublicKeyAuthentication {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer objectForKey:@"p256_public"];
    NSString *privateKey = [validPublicKeyProtectedServer objectForKey:@"p256_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    NSLog(@"turn on trace logging");
    libssh2_trace([session rawSession], ~0);

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"P256 ECDSA authentication should not throw");

    XCTAssertTrue([session isAuthorized], @"P256 ECDSA authentication should work");
}

- (void)testP256ECDSASignCallback {
    NSString *host = [validPasswordProtectedServer objectForKey:@"host"];
    NSString *username = [validPasswordProtectedServer objectForKey:@"user"];
    
    NSString *privateKeyPath = [validPublicKeyProtectedServer objectForKey:@"p256_key_pem"];
    NSString *publicKeyPath = [validPublicKeyProtectedServer objectForKey:@"p256_public"];
    
    NSData *scalar = [self extractScalarFromPKCS8:privateKeyPath];
    XCTAssertNotNil(scalar, @"Should extract scalar from P256 private key");
    if (!scalar) return;
    
    NSData *Q = [self parseOpenSSHPub:publicKeyPath];
    XCTAssertNotNil(Q, @"Should parse Q from P256 public key");
    if (!Q) return;
    
    // Build 97-byte private key blob: [Q || scalar]
    NSMutableData *privBlob = [NSMutableData dataWithLength:97];
    memcpy(privBlob.mutableBytes, Q.bytes, 65);
    memcpy(privBlob.mutableBytes+65, scalar.bytes, 32);
    
    // Extract public key data for SSH authentication
    NSString *publicKeyLine = [NSString stringWithContentsOfFile:publicKeyPath encoding:NSUTF8StringEncoding error:nil];
    NSArray *parts = [[publicKeyLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@" "];
    NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:parts[1] options:0];
    [self logHex:@"publicKeyData" data:publicKeyData.bytes len:publicKeyData.length];
    NSData *pubPub = [publicKeyData subdataWithRange:NSMakeRange(39,65)];
    [self logHex:@"pubPub" data:pubPub.bytes len:pubPub.length];
    XCTAssertNotNil(publicKeyData, @"Should decode P256 public key");
    if (!publicKeyData) return;

    NMSSHSession *session = [NMSSHSession connectToHost:host withUsername:username];
    XCTAssertTrue([session isConnected], @"Should connect to test server");
    if (![session isConnected]) return;
    
    // Create P256 signing callback using SecKey
    int(^signCallback)(NSData *, NSData **) = ^int(NSData *data, NSData **signature) {
        [self logHex:@"challenge:" data: data.bytes len: data.length];
        
        @try {
            CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL, 0,
                &kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
            CFDictionarySetValue(attrs, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
            CFDictionarySetValue(attrs, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
            CFDictionarySetValue(attrs, kSecAttrKeySizeInBits, (__bridge CFNumberRef)@(256));
            
            CFErrorRef error = NULL;
            SecKeyRef privateKey = SecKeyCreateWithData((__bridge CFDataRef)privBlob, attrs, &error);
            CFRelease(attrs);
            if (!privateKey) {
                if (error) CFRelease(error);
                return -1;
            }

            SecKeyRef secPubKey = SecKeyCopyPublicKey(privateKey);
            NSData *exportedPub = (__bridge_transfer NSData*)SecKeyCopyExternalRepresentation(secPubKey, &error);
            [self logHex:@"exportedPub" data:exportedPub.bytes len:exportedPub.length];
            
            // Sign the raw data (let SecKey do the hashing with SHA256)
            CFDataRef signatureData = SecKeyCreateSignature(privateKey, 
                                                           kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                           (__bridge CFDataRef)data, 
                                                           &error);
            CFRelease(privateKey);
            
            if (!signatureData) {
                if (error) CFRelease(error);
                return -1;
            }
            
            NSData *asn1Signature = (__bridge NSData *)signatureData;
            [self logHex:@"asn1:" data: asn1Signature.bytes len: asn1Signature.length];
            NSData *sshSignature = [self convertASN1SignatureToSSH:asn1Signature];
            [self logHex:@"sshSignature:" data: sshSignature.bytes len: sshSignature.length];
            CFRelease(signatureData);
            
            if (!sshSignature) {
                return -1;
            }
            
            *signature = [sshSignature copy];
            NSLog(@"signature callback success");
            return 0;
            
        } @catch (NSException *exception) {
            return -1;
        }
    };

    NSLog(@"turn on trace logging");
    libssh2_trace([session rawSession], ~0);
    
    int auth_error = [session authenticateByInMemoryPublicKey:publicKeyData signCallback:signCallback];
    NSLog(@"auth_error: %d", auth_error);
    XCTAssertTrue(auth_error == 0, @"Callback auth should work");
    
    if (![session isAuthorized]) {
      return;
    }

    NMSSHChannel *channel = [[NMSSHChannel alloc] initWithSession:session];

    NSError *error = nil;
    XCTAssertNoThrow([channel execute:[validPasswordProtectedServer objectForKey:@"execute_command"]
                               error:&error],
                    @"P256 SignCallback: Execution should not throw an exception");

    XCTAssertTrue(error == nil, @"P256 SignCallback: Exec after sign should work");

    NSLog(@"P256 SignCallback: %@", [channel lastResponse]);

    XCTAssertEqualObjects([channel lastResponse],
                         [validPasswordProtectedServer objectForKey:@"execute_expected_response"],
                         @"P256 SignCallback: Execution returns the expected response");
}

// -----------------------------------------------------------------------------
// ED25519 KEY TESTS
// -----------------------------------------------------------------------------

- (void)testEd25519PublicKeyAuthentication {
    NSString *host = [validPublicKeyProtectedServer objectForKey:@"host"];
    NSString *username = [validPublicKeyProtectedServer objectForKey:@"user"];
    NSString *publicKey = [validPublicKeyProtectedServer objectForKey:@"ed25519_key"];

    session = [NMSSHSession connectToHost:host withUsername:username];

    XCTAssertNoThrow([session authenticateByPublicKey:publicKey
                                          privateKey:[publicKey stringByDeletingPathExtension]
                                         andPassword:nil],
                    @"Ed25519 authentication should not throw");

    XCTAssertTrue([session isAuthorized], @"Ed25519 authentication should work");
}

- (void)logHex:(NSString *)prefix data:(unsigned char *)pdata len:(NSUInteger)len {
  NSMutableString *s = [NSMutableString string];
  for (NSUInteger i = 0; i < len; i++) {
      [s appendFormat:@"%02x", pdata[i]];
  }
  NSLog(@"%@(%u): %@", prefix, len, s);
}

@end
