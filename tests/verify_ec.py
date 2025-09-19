#!/usr/bin/env python3
import sys
import binascii
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
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

    try:
        public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), pubkey_bytes)
        public_key.verify(signature_bytes, message_bytes, ec.ECDSA(hashes.SHA256()))
        print("Signature is valid!")
    except InvalidSignature:
        print("Signature is INVALID!")
        sys.exit(1)
    except Exception as e:
        print(f"Error verifying signature: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
