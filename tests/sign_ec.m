#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

@implementation NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSString *)hex {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */

    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer)
        return [NSString string];

    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];

    return [NSString stringWithString:hexString];
}

@end

NSString *hex(NSData *data) { return [data hex]; }

// Convert hex string to NSData
NSData* hexToData(NSString* hex) {
    NSMutableData* data = [NSMutableData data];
    for (NSUInteger i = 0; i < hex.length; i += 2) {
        NSString* byteString = [hex substringWithRange:NSMakeRange(i, 2)];
        unsigned byte;
        [[NSScanner scannerWithString:byteString] scanHexInt:&byte];
        uint8_t b = byte;
        [data appendBytes:&b length:1];
    }
    return data;
}

// Combine public key (Q) and private scalar into 97-byte SEC1 blob
NSData* makeSec1Key(NSData* pub, NSData* priv) {
    NSMutableData *blob = [NSMutableData dataWithLength:97];
    memcpy(blob.mutableBytes, pub.bytes, 65);       // Q
    memcpy(blob.mutableBytes + 65, priv.bytes, 32); // scalar
    return blob;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 4) {
            NSLog(@"Usage: %s <privkey_hex> <pubkey_hex> <message_hex>", argv[0]);
            return 1;
        }

        NSData *privData = hexToData([NSString stringWithUTF8String:argv[1]]);
        NSData *pubData  = hexToData([NSString stringWithUTF8String:argv[2]]);
        NSData *msgData  = hexToData([NSString stringWithUTF8String:argv[3]]);

        NSData *sec1Key = makeSec1Key(pubData, privData);

        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL, 0,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
        CFDictionarySetValue(attrs, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
        CFDictionarySetValue(attrs, kSecAttrKeySizeInBits, (__bridge CFNumberRef)@(256));

        CFErrorRef err = NULL;
        SecKeyRef privKey = SecKeyCreateWithData((__bridge CFDataRef)sec1Key, attrs, &err);
        if (!privKey) {
            NSLog(@"Failed to create key: %@", err);
            return 1;
        }
        SecKeyRef exportedPubKey = SecKeyCopyPublicKey(privKey);
        NSData *exportedPub = (__bridge_transfer NSData*)SecKeyCopyExternalRepresentation(exportedPubKey, &err);
        NSLog(@"Derived public key (65 bytes): %@", hex(exportedPub));

        // Compute SHA-256 digest of the message
        NSLog(@"message: %@", hex(msgData));
        NSMutableData *digest = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(msgData.bytes, (CC_LONG)msgData.length, digest.mutableBytes);
        NSLog(@"digest: %@", hex(digest));

        // Sign the digest
        NSData *sig = (__bridge_transfer NSData *)
            SecKeyCreateSignature(privKey,
                                  kSecKeyAlgorithmECDSASignatureDigestX962SHA256,
                                  (__bridge CFDataRef)digest,
                                  &err);
        if (!sig) {
            NSLog(@"Failed to sign: %@", err);
            return 1;
        }

        NSLog(@"sig: %@", hex(sig));


        NSData *sig2 = (__bridge_transfer NSData *)
            SecKeyCreateSignature(privKey,
                                  kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                  (__bridge CFDataRef)msgData,
                                  &err);
        NSLog(@"sig2: %@", hex(sig2));

    }
    return 0;
}
