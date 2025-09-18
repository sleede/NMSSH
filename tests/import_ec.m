#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Base64 helper
NSString* b64(NSData* d) { return [d base64EncodedStringWithOptions:0]; }

// Extract 32-byte scalar from PKCS#8 PEM
NSData* extractScalarFromPKCS8(NSString* path) {
    NSString *pem = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    pem = [pem stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    pem = [pem stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    pem = [pem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSRange start = [pem rangeOfString:@"-----BEGIN PRIVATE KEY-----"];
    NSRange end   = [pem rangeOfString:@"-----END PRIVATE KEY-----"];
    NSString *b64str = [pem substringWithRange:NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start))];
    b64str = [[b64str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    NSData *der = [[NSData alloc] initWithBase64EncodedString:b64str options:0];

    NSData *scalar = [der subdataWithRange:NSMakeRange(der.length-32,32)];
    NSLog(@"Original scalar (32 bytes): %@", b64(scalar));
    return scalar;
}

// Parse OpenSSH public key, extract Q
NSData* parseOpenSSHPub(NSString* path) {
    NSString *line = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [line componentsSeparatedByString:@" "];
    NSData *blob = [[NSData alloc] initWithBase64EncodedString:parts[1] options:0];

    const uint8_t *p = (const uint8_t*)blob.bytes; size_t len = blob.length;
    uint32_t l1 = ntohl(*(uint32_t*)p); p+=4; len-=4; p+=l1; len-=l1;
    uint32_t l2 = ntohl(*(uint32_t*)p); p+=4; len-=4; p+=l2; len-=l2;
    uint32_t qlen = ntohl(*(uint32_t*)p); p+=4; len-=4;
    NSData *Q = [NSData dataWithBytes:p length:qlen];
    NSLog(@"Original Q (65 bytes): %@", b64(Q));
    return Q;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 3) { NSLog(@"Usage: %s priv.pem pub.pub", argv[0]); return 1; }

        NSData *scalar = extractScalarFromPKCS8([NSString stringWithUTF8String:argv[1]]);
        NSData *Q = parseOpenSSHPub([NSString stringWithUTF8String:argv[2]]);

        // Build 97-byte private key blob: [Q || scalar]
        NSMutableData *privBlob = [NSMutableData dataWithLength:97];
        memcpy(privBlob.mutableBytes, Q.bytes, 65);
        memcpy(privBlob.mutableBytes+65, scalar.bytes, 32);
        NSLog(@"Private key blob (97 bytes): %@", b64(privBlob));

        // Create SecKey private key
        CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL, 0,
            &kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
        CFDictionarySetValue(attrs, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
        CFDictionarySetValue(attrs, kSecAttrKeySizeInBits, (__bridge CFNumberRef)@(256));

        CFErrorRef err = NULL;
        SecKeyRef privKey = SecKeyCreateWithData((__bridge CFDataRef)privBlob, attrs, &err);
        CFRelease(attrs);
        if (!privKey) { NSLog(@"❌ SecKeyCreateWithData failed: %@", (__bridge NSError*)err); return 1; }

        // Export private key
        NSData *exportedPriv = (__bridge_transfer NSData*)SecKeyCopyExternalRepresentation(privKey, &err);
        NSLog(@"Exported private key (97 bytes): %@", b64(exportedPriv));
        BOOL privMatch = [privBlob isEqualToData:exportedPriv];
        NSLog(@"Private key matches original blob: %@", privMatch ? @"YES" : @"NO");

        // Derive public key
        SecKeyRef pubKey = SecKeyCopyPublicKey(privKey);
        NSData *exportedPub = (__bridge_transfer NSData*)SecKeyCopyExternalRepresentation(pubKey, &err);
        NSLog(@"Derived public key (65 bytes): %@", b64(exportedPub));
        BOOL pubMatch = [exportedPub isEqualToData:Q];
        NSLog(@"Derived public key matches original Q: %@", pubMatch ? @"YES" : @"NO");

        CFRelease(privKey); CFRelease(pubKey);
    }
    return 0;
}
