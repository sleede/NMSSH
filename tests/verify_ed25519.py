#!/usr/bin/env python3
import sys
import binascii
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <pubkey_hex> <signature_hex> <message_hex>")
        sys.exit(1)

    pubkey_hex = sys.argv[1]
    signature_hex = sys.argv[2]
    message_hex = sys.argv[3]

    try:
        pubkey_bytes = binascii.unhexlify(pubkey_hex)
        signature_bytes = binascii.unhexlify(signature_hex)
        message_bytes = binascii.unhexlify(message_hex)
    except binascii.Error as e:
        print(f"Error decoding hex: {e}")
        sys.exit(1)

    if len(pubkey_bytes) != 32:
        print(f"Error: Ed25519 public key must be 32 bytes, got {len(pubkey_bytes)}")
        sys.exit(1)

    if len(signature_bytes) != 64:
        print(f"Error: Ed25519 signature must be 64 bytes, got {len(signature_bytes)}")
        sys.exit(1)

    try:
        public_key = ed25519.Ed25519PublicKey.from_public_bytes(pubkey_bytes)
        public_key.verify(signature_bytes, message_bytes)
        print("Ed25519 signature is valid!")
    except InvalidSignature:
        print("Ed25519 signature is INVALID!")
        sys.exit(1)
    except Exception as e:
        print(f"Error verifying Ed25519 signature: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
