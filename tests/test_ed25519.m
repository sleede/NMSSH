#import <Foundation/Foundation.h>

// Import the Swift bridge
#import "Ed25519Bridge-Swift.h"

NSString* dataToHex(NSData* data) {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSMutableString *hex = [NSMutableString stringWithCapacity:[data length] * 2];
    for (NSUInteger i = 0; i < [data length]; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

// Extract Ed25519 private key from OpenSSH format
NSData* extractEd25519PrivateKey(NSString* keyPath) {
    NSString* keyContent = [NSString stringWithContentsOfFile:keyPath encoding:NSUTF8StringEncoding error:nil];
    if (!keyContent) return nil;
    
    // Remove header/footer and decode base64
    NSString* base64 = [keyContent stringByReplacingOccurrencesOfString:@"-----BEGIN OPENSSH PRIVATE KEY-----" withString:@""];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"-----END OPENSSH PRIVATE KEY-----" withString:@""];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    base64 = [base64 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSData* keyData = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (!keyData) return nil;
    
    // Parse OpenSSH private key format to extract the 32-byte Ed25519 private key
    if (keyData.length < 135) return nil;
    
    // Extract the 32-byte private key (this is the seed)
    NSData* privateKey = [keyData subdataWithRange:NSMakeRange(103, 32)];
    return privateKey;
}

// Extract Ed25519 public key from SSH public key format
NSData* extractEd25519PublicKey(NSString* pubKeyPath) {
    NSString* pubContent = [NSString stringWithContentsOfFile:pubKeyPath encoding:NSUTF8StringEncoding error:nil];
    if (!pubContent) return nil;
    
    NSArray* parts = [pubContent componentsSeparatedByString:@" "];
    if (parts.count < 2) return nil;
    
    NSData* keyData = [[NSData alloc] initWithBase64EncodedString:parts[1] options:0];
    if (!keyData) return nil;
    
    // SSH public key format: [4 bytes length][algorithm][4 bytes length][32 bytes public key]
    if (keyData.length < 51) return nil;
    
    // Extract the 32-byte public key
    NSData* publicKey = [keyData subdataWithRange:NSMakeRange(19, 32)];
    return publicKey;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            NSLog(@"Usage: %s <private_key_path> <public_key_path>", argv[0]);
            return 1;
        }
        
        NSLog(@"Testing Ed25519 key extraction and CryptoKit integration...");
        
        NSString *privateKeyPath = [NSString stringWithUTF8String:argv[1]];
        NSString *publicKeyPath = [NSString stringWithUTF8String:argv[2]];
        
        NSData* extractedPrivateKey = extractEd25519PrivateKey(privateKeyPath);
        NSData* extractedPublicKey = extractEd25519PublicKey(publicKeyPath);
        
        if (!extractedPrivateKey) {
            NSLog(@"❌ Failed to extract private key");
            return 1;
        }
        
        if (!extractedPublicKey) {
            NSLog(@"❌ Failed to extract public key");
            return 1;
        }
        
        NSLog(@"✓ Extracted private key (%lu bytes): %@", (unsigned long)extractedPrivateKey.length, dataToHex(extractedPrivateKey));
        NSLog(@"✓ Extracted public key (%lu bytes): %@", (unsigned long)extractedPublicKey.length, dataToHex(extractedPublicKey));
        
        // Create CryptoKit private key from extracted data
        id cryptoKitPrivateKey = [Ed25519Bridge createPrivateKeyFrom:extractedPrivateKey];
        if (!cryptoKitPrivateKey) {
            NSLog(@"❌ Failed to create CryptoKit private key");
            return 1;
        }
        NSLog(@"✓ Created CryptoKit private key");
        
        // Get public key from CryptoKit private key
        NSData* derivedPublicKey = [Ed25519Bridge getPublicKeyFrom:cryptoKitPrivateKey];
        if (!derivedPublicKey) {
            NSLog(@"❌ Failed to derive public key from CryptoKit private key");
            return 1;
        }
        NSLog(@"✓ Derived public key (%lu bytes): %@", (unsigned long)derivedPublicKey.length, dataToHex(derivedPublicKey));
        
        // Verify public keys match
        if ([extractedPublicKey isEqualToData:derivedPublicKey]) {
            NSLog(@"✅ Public keys match!");
        } else {
            NSLog(@"❌ Public keys don't match!");
            NSLog(@"   Extracted: %@", dataToHex(extractedPublicKey));
            NSLog(@"   Derived:   %@", dataToHex(derivedPublicKey));
            return 1;
        }
        
        // Test signing
        NSString* testMessage = @"Hello, Ed25519!";
        NSData* messageData = [testMessage dataUsingEncoding:NSUTF8StringEncoding];
        
        NSData* signature = [Ed25519Bridge signData:messageData with:cryptoKitPrivateKey];
        if (!signature) {
            NSLog(@"❌ Failed to sign message");
            return 1;
        }
        NSLog(@"✓ Signed message (%lu bytes): %@", (unsigned long)signature.length, dataToHex(signature));
        
        NSLog(@"🎉 All Ed25519 tests passed!");
    }
    return 0;
}
