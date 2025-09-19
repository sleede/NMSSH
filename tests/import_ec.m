#import <Foundation/Foundation.h>
#import <Security/Security.h>

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

NSArray<NSData *> *parseECDSASignatureStrict(NSData *asn1Signature) {
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

NSString* hex(NSData* d) { return [d hex]; }

NSString* b64(NSData* d) { return [d base64EncodedStringWithOptions:0]; }

NSData* dataFromHex(NSString* hex) {
    NSMutableData *data = [NSMutableData data];
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    NSString *cleanHex = [[hex componentsSeparatedByCharactersInSet:[hexSet invertedSet]] componentsJoinedByString:@""];
    for (NSUInteger i = 0; i < cleanHex.length; i += 2) {
        NSString *byteStr = [cleanHex substringWithRange:NSMakeRange(i, 2)];
        unsigned int byte;
        [[NSScanner scannerWithString:byteStr] scanHexInt:&byte];
        uint8_t b = byte & 0xFF;
        [data appendBytes:&b length:1];
    }
    return data;
}

static BOOL read_length(const uint8_t *bytes, NSUInteger bytesLen, NSUInteger *pos, NSUInteger *outLen) {
    if (*pos >= bytesLen) return NO;
    uint8_t b = bytes[(*pos)++];
    if ((b & 0x80) == 0) {
        *outLen = b;
        return (*pos <= bytesLen);
    }
    uint8_t num = b & 0x7F;
    if (num == 0 || num > 4) return NO; // reject weird lengths
    if ((*pos + num) > bytesLen) return NO;
    NSUInteger val = 0;
    for (uint8_t i = 0; i < num; ++i) {
        val = (val << 8) | bytes[(*pos)++];
    }
    *outLen = val;
    return YES;
}

static BOOL expect_tag(const uint8_t *bytes, NSUInteger bytesLen, NSUInteger *pos, uint8_t expectedTag, NSUInteger *outLen) {
    if (*pos >= bytesLen) return NO;
    uint8_t tag = bytes[(*pos)++];
    if (tag != expectedTag) return NO;
    if (!read_length(bytes, bytesLen, pos, outLen)) return NO;
    if ((*pos + *outLen) > bytesLen) return NO;
    return YES;
}

NSData* extractScalarFromPKCS8(NSString* path) {
    NSError *err = nil;
    NSString *pem = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    if (!pem) {
        NSLog(@"Failed to read PEM: %@", err);
        return nil;
    }

    pem = [pem stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    pem = [pem stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    pem = [pem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSRange start = [pem rangeOfString:@"-----BEGIN PRIVATE KEY-----"];
    NSRange end   = [pem rangeOfString:@"-----END PRIVATE KEY-----"];
    if (start.location == NSNotFound || end.location == NSNotFound) {
        NSLog(@"PEM delimiters not found");
        return nil;
    }
    NSString *b64str = [pem substringWithRange:NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start))];
    b64str = [[b64str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    NSData *der = [[NSData alloc] initWithBase64EncodedString:b64str options:0];
    if (!der) {
        NSLog(@"Base64 decode failed");
        return nil;
    }

    const uint8_t *bytes = der.bytes;
    NSUInteger bytesLen = der.length;
    NSUInteger pos = 0;

    // Outer SEQUENCE
    NSUInteger seqLen = 0;
    if (!expect_tag(bytes, bytesLen, &pos, 0x30, &seqLen)) { NSLog(@"Not a SEQUENCE (outer)"); return nil; }
    NSUInteger seqEnd = pos + seqLen;
    if (seqEnd > bytesLen) { NSLog(@"Outer sequence length out of bounds"); return nil; }

    // version INTEGER (we can skip it)
    NSUInteger intLen = 0;
    if (!expect_tag(bytes, bytesLen, &pos, 0x02, &intLen)) { NSLog(@"Missing version INTEGER"); return nil; }
    pos += intLen;
    if (pos > seqEnd) { NSLog(@"version INTEGER overflow"); return nil; }

    // algorithm identifier: SEQUENCE -- skip it
    NSUInteger algSeqLen = 0;
    if (!expect_tag(bytes, bytesLen, &pos, 0x30, &algSeqLen)) { NSLog(@"Missing AlgorithmIdentifier SEQUENCE"); return nil; }
    pos += algSeqLen;
    if (pos > seqEnd) { NSLog(@"AlgorithmIdentifier overflow"); return nil; }

    // Now we expect the privateKey OCTET STRING
    NSUInteger octetLen = 0;
    if (!expect_tag(bytes, bytesLen, &pos, 0x04, &octetLen)) { NSLog(@"Unexpected tag (not OCTET STRING)"); return nil; }
    if ((pos + octetLen) > seqEnd) { NSLog(@"OCTET STRING length goes past outer sequence"); return nil; }

    // The contents of that OCTET STRING are a DER-encoded ECPrivateKey structure.
    const uint8_t *ecPriv = bytes + pos;
    NSUInteger ecPrivLen = octetLen;
    pos += octetLen; // move pos to end of outer sequence component (not strictly needed)

    // Parse ECPrivateKey: expect SEQUENCE
    NSUInteger ecPos = 0;
    if (ecPrivLen < 2) { NSLog(@"ECPrivateKey too small"); return nil; }
    if (ecPriv[ecPos++] != 0x30) { NSLog(@"ECPrivateKey not a SEQUENCE"); return nil; }
    // read length of ECPrivateKey
    NSUInteger ecSeqLen = 0;
    NSUInteger tmpPos = ecPos;
    if (!read_length(ecPriv, ecPrivLen, &ecPos, &ecSeqLen)) { NSLog(@"Failed to read ECPrivateKey length"); return nil; }
    if (ecSeqLen > (ecPrivLen - ecPos)) { NSLog(@"ECPrivateKey length out of bounds"); return nil; }

    // version INTEGER inside ECPrivateKey (skip)
    if (!expect_tag(ecPriv, ecPrivLen, &ecPos, 0x02, &intLen)) { NSLog(@"ECPrivateKey missing version INTEGER"); return nil; }
    ecPos += intLen;

    // privateKey OCTET STRING: this contains the raw scalar (usually 32 bytes for P-256)
    if (!expect_tag(ecPriv, ecPrivLen, &ecPos, 0x04, &octetLen)) { NSLog(@"ECPrivateKey missing privateKey OCTET STRING"); return nil; }
    if (octetLen == 0) { NSLog(@"privateKey OCTET STRING is empty"); return nil; }
    if ((ecPos + octetLen) > ecPrivLen) { NSLog(@"privateKey OCTET STRING out of bounds"); return nil; }

    NSData *scalar = [NSData dataWithBytes:(ecPriv + ecPos) length:octetLen];
    // scalar may be 32 bytes or sometimes has a leading 0 if encoded as unsigned integer. Normalize if needed:
    if (scalar.length == 33 && ((uint8_t *)scalar.bytes)[0] == 0x00) {
        scalar = [scalar subdataWithRange:NSMakeRange(1, 32)];
    }

    if (scalar.length != 32) {
        NSLog(@"Warning: extracted scalar length %lu (expected 32).", (unsigned long)scalar.length);
    }

    NSLog(@"Original scalar (%lu bytes): %@", (unsigned long)scalar.length,
          ({ // inline hex formatter
              const unsigned char *b = scalar.bytes;
              NSMutableString *s = [NSMutableString stringWithCapacity:scalar.length*2];
              for (NSUInteger i = 0; i < scalar.length; ++i) [s appendFormat:@"%02x", b[i]];
              s;
          }));
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
    NSLog(@"Original Q (65 bytes): %@", hex(Q));
    return Q;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 4) { NSLog(@"Usage: %s priv.pem pub.pub hexmsg", argv[0]); return 1; }

        NSData *scalar = extractScalarFromPKCS8([NSString stringWithUTF8String:argv[1]]);
        NSData *Q = parseOpenSSHPub([NSString stringWithUTF8String:argv[2]]);
        NSString *hexMsg = [NSString stringWithUTF8String:argv[3]];
        NSData *msg = dataFromHex(hexMsg);

        // Build 97-byte private key blob: [Q || scalar]
        NSMutableData *privBlob = [NSMutableData dataWithLength:97];
        memcpy(privBlob.mutableBytes, Q.bytes, 65);
        memcpy(privBlob.mutableBytes+65, scalar.bytes, 32);
        NSLog(@"Private key blob (97 bytes): %@", hex(privBlob));

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
        NSLog(@"Exported private key (97 bytes): %@", hex(exportedPriv));
        BOOL privMatch = [privBlob isEqualToData:exportedPriv];
        NSLog(@"Private key matches original blob: %@", privMatch ? @"YES" : @"NO");

        // Derive public key
        SecKeyRef pubKey = SecKeyCopyPublicKey(privKey);
        NSData *exportedPub = (__bridge_transfer NSData*)SecKeyCopyExternalRepresentation(pubKey, &err);
        NSLog(@"Derived public key (65 bytes): %@", hex(exportedPub));
        BOOL pubMatch = [exportedPub isEqualToData:Q];
        NSLog(@"Derived public key matches original Q: %@", pubMatch ? @"YES" : @"NO");

        NSLog(@"message to sign: (%lu bytes): %@", msg.length, hex(msg));
        NSData *signature = (__bridge_transfer NSData*)SecKeyCreateSignature(privKey,
            kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
            (__bridge CFDataRef)msg,
            &err);
        if (!signature) { NSLog(@"❌ Signing failed: %@", (__bridge NSError*)err); return 1; }

        NSLog(@"Signature (%lu bytes): %@", (unsigned long)signature.length, hex(signature));

        NSArray *r_s = parseECDSASignatureStrict(signature);
        NSData *r = r_s[0];
        NSData *s = r_s[1];
        NSLog(@"r (%lu bytes): %@", r.length, hex(r));
        NSLog(@"s (%lu bytes): %@", s.length, hex(s));

        CFRelease(privKey); CFRelease(pubKey);
    }
    return 0;
}
