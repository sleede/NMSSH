#import <Foundation/Foundation.h>
#import <Security/Security.h>

NSString* dataToBase64(NSData* data) {
    return [data base64EncodedStringWithOptions:0];
}

// P-256 curve order
static const uint8_t P256_N[] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84, 0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51
};

NSData* generatePrivateKeyScalar() {
    NSMutableData* keyData = [NSMutableData dataWithLength:32];
    uint8_t* bytes = (uint8_t*)keyData.mutableBytes;

    // Use rand() to generate random bytes
    srand((unsigned int)time(NULL));
    for (int i = 0; i < 32; i++) {
        bytes[i] = rand() & 0xFF;
    }

    // Ensure it's less than the curve order N
    int needs_reduction = 0;
    for (int i = 0; i < 32; i++) {
        if (bytes[i] > P256_N[i]) {
            needs_reduction = 1;
            break;
        } else if (bytes[i] < P256_N[i]) {
            break;
        }
    }

    if (needs_reduction) {
        uint64_t borrow = 0;
        for (int i = 31; i >= 0; i--) {
            uint64_t diff = (uint64_t)bytes[i] - P256_N[i] - borrow;
            bytes[i] = diff & 0xFF;
            borrow = (diff >> 8) & 1;
        }
    }

    // Ensure it's not zero
    int is_zero = 1;
    for (int i = 0; i < 32; i++) {
        if (bytes[i] != 0) {
            is_zero = 0;
            break;
        }
    }
    if (is_zero) {
        bytes[31] = 1;
    }

    return keyData;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Generating P-256 private key using rand()...");

        // Generate 32-byte private key scalar using rand()
        NSData* privateScalar = generatePrivateKeyScalar();
        NSLog(@"✓ Generated 32-byte private key scalar");
        NSString* originalScalarB64 = dataToBase64(privateScalar);
        NSLog(@"Original 32-byte scalar: %@", originalScalarB64);

        // First, create a temporary key to derive the public key
        // We'll import our private scalar and let SecKey derive the public key
        CFMutableDictionaryRef tempKeyAttrs = CFDictionaryCreateMutable(
            kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks
        );
        CFDictionarySetValue(tempKeyAttrs, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
        CFDictionarySetValue(tempKeyAttrs, kSecAttrKeyClass, kSecAttrKeyClassPrivate);
        CFDictionarySetValue(tempKeyAttrs, kSecAttrKeySizeInBits, (__bridge CFNumberRef)@(256));

        // Create the 97-byte private key format: [65-byte placeholder public key][32-byte private scalar]
        NSMutableData* tempPrivateKeyData = [NSMutableData dataWithLength:97];
        uint8_t* tempBytes = (uint8_t*)tempPrivateKeyData.mutableBytes;

        // Put placeholder public key (we'll fix this after we get the real public key)
        tempBytes[0] = 0x04; // Uncompressed format marker
        // Copy private scalar to the end
        memcpy(tempBytes + 65, privateScalar.bytes, 32);

        // Try to create a temporary key just to get the public key derivation
        // We'll use SecKey generation first, then replace with our scalar
        CFMutableDictionaryRef keyGenParams = CFDictionaryCreateMutable(
            kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks
        );

        CFDictionarySetValue(keyGenParams, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
        CFDictionarySetValue(keyGenParams, kSecAttrKeySizeInBits, (__bridge CFNumberRef)@(256));
        CFDictionarySetValue(keyGenParams, kSecAttrIsPermanent, kCFBooleanFalse);

        // Generate a temporary key pair to get the public key derivation working
        SecKeyRef tempPrivateKey = NULL;
        SecKeyRef tempPublicKey = NULL;
        OSStatus status = SecKeyGeneratePair(keyGenParams, &tempPublicKey, &tempPrivateKey);
        CFRelease(keyGenParams);

        if (status != errSecSuccess) {
            NSLog(@"Temporary key generation failed with status: %d", (int)status);
            CFRelease(tempKeyAttrs);
            return 1;
        }

        // Export the generated private key to see the format, then replace the scalar
        CFErrorRef exportError = NULL;
        NSData* tempExportedKey = (NSData*)SecKeyCopyExternalRepresentation(tempPrivateKey, &exportError);
        if (!tempExportedKey) {
            NSLog(@"Failed to export temporary key: %@", (__bridge NSError*)exportError);
            if (exportError) CFRelease(exportError);
            CFRelease(tempPrivateKey);
            CFRelease(tempPublicKey);
            CFRelease(tempKeyAttrs);
            return 1;
        }

        // Now create our custom private key by replacing the scalar part
        NSMutableData* customPrivateKeyData = [tempExportedKey mutableCopy];
        uint8_t* customBytes = (uint8_t*)customPrivateKeyData.mutableBytes;
        // Replace the last 32 bytes (private scalar) with our rand() generated scalar
        memcpy(customBytes + 65, privateScalar.bytes, 32);

        NSLog(@"✓ Created custom private key with rand() scalar");

        // Print private key BEFORE import
        NSString* privateKeyBeforeImport = dataToBase64(customPrivateKeyData);
        NSLog(@"\n=== Private Key BEFORE Import ===");
        NSLog(@"Length: %lu bytes", (unsigned long)customPrivateKeyData.length);
        NSLog(@"Base64: %@", privateKeyBeforeImport);

        // Import our custom private key
        CFErrorRef importError = NULL;
        SecKeyRef importedPrivateKey = SecKeyCreateWithData(
            (__bridge CFDataRef)customPrivateKeyData,
            tempKeyAttrs,
            &importError
        );
        CFRelease(tempKeyAttrs);

        if (!importedPrivateKey) {
            NSLog(@"Failed to import custom private key: %@", (__bridge NSError*)importError);
            if (importError) CFRelease(importError);
            CFRelease(tempPrivateKey);
            CFRelease(tempPublicKey);
            return 1;
        }

        NSLog(@"✓ Successfully imported custom private key");

        // Derive public key from our custom private key
        SecKeyRef derivedPublicKey = SecKeyCopyPublicKey(importedPrivateKey);
        if (!derivedPublicKey) {
            NSLog(@"Failed to derive public key from custom private key");
            CFRelease(importedPrivateKey);
            CFRelease(tempPrivateKey);
            CFRelease(tempPublicKey);
            return 1;
        }

        NSLog(@"✓ Derived public key from custom private key");

        // Export the imported private key to verify it's the same
        CFErrorRef privateExportError = NULL;
        NSData* exportedPrivateKeyData = (NSData*)SecKeyCopyExternalRepresentation(importedPrivateKey, &privateExportError);
        if (!exportedPrivateKeyData) {
            NSLog(@"Failed to export imported private key: %@", (__bridge NSError*)privateExportError);
            if (privateExportError) CFRelease(privateExportError);
            CFRelease(importedPrivateKey);
            CFRelease(derivedPublicKey);
            CFRelease(tempPrivateKey);
            CFRelease(tempPublicKey);
            return 1;
        }

        // Export the final public key
        CFErrorRef publicExportError = NULL;
        NSData* publicKeyData = (NSData*)SecKeyCopyExternalRepresentation(derivedPublicKey, &publicExportError);
        if (!publicKeyData) {
            NSLog(@"Failed to export public key: %@", (__bridge NSError*)publicExportError);
            if (publicExportError) CFRelease(publicExportError);
            CFRelease(importedPrivateKey);
            CFRelease(derivedPublicKey);
            CFRelease(tempPrivateKey);
            CFRelease(tempPublicKey);
            return 1;
        }

        // Print base64 encoded keys
        NSString* privateKeyB64 = dataToBase64(customPrivateKeyData);
        NSString* exportedPrivateKeyB64 = dataToBase64(exportedPrivateKeyData);
        NSString* publicKeyB64 = dataToBase64(publicKeyData);
        NSString* privateScalarB64 = dataToBase64(privateScalar);

        NSLog(@"\n=== P-256 Key Pair (Base64) ===");
        NSLog(@"Private Scalar (%lu bytes):", (unsigned long)privateScalar.length);
        NSLog(@"%@", privateScalarB64);
        NSLog(@"\nPrivate Key BEFORE Import (%lu bytes):", (unsigned long)customPrivateKeyData.length);
        NSLog(@"%@", privateKeyB64);
        NSLog(@"\nPrivate Key AFTER Import (%lu bytes):", (unsigned long)exportedPrivateKeyData.length);
        NSLog(@"%@", exportedPrivateKeyB64);
        NSLog(@"\nPublic Key (%lu bytes):", (unsigned long)publicKeyData.length);
        NSLog(@"%@", publicKeyB64);

        // Verify private keys are identical
        BOOL privateKeysMatch = [customPrivateKeyData isEqualToData:exportedPrivateKeyData];
        NSLog(@"\n=== Verification ===");
        NSLog(@"Private keys match: %@", privateKeysMatch ? @"✓ YES" : @"✗ NO");
        if (!privateKeysMatch) {
            NSLog(@"⚠️  WARNING: Private key changed during import/export cycle!");
        }

        // Extract and compare the 32-byte scalar from the imported key
        NSData* extractedScalar = [exportedPrivateKeyData subdataWithRange:NSMakeRange(65, 32)];
        NSString* extractedScalarB64 = dataToBase64(extractedScalar);
        NSLog(@"Extracted 32-byte scalar from imported key: %@", extractedScalarB64);

        BOOL scalarsMatch = [privateScalar isEqualToData:extractedScalar];
        NSLog(@"Original vs extracted scalars match: %@", scalarsMatch ? @"✓ YES" : @"✗ NO");
        if (!scalarsMatch) {
            NSLog(@"⚠️  WARNING: Private scalar changed during import/export cycle!");
        }

        // Cleanup
        CFRelease(importedPrivateKey);
        CFRelease(derivedPublicKey);
        CFRelease(tempPrivateKey);
        CFRelease(tempPublicKey);

        NSLog(@"\n✓ Private key scalar generated using rand()");
        NSLog(@"✓ Public key derived using SecKey framework");
        NSLog(@"✓ All keys were memory-resident only (non-permanent)");
        NSLog(@"✓ Program completed successfully");
    }
    return 0;
}