#!/usr/bin/env python3
import sys
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <private-key-hex>")
    sys.exit(1)

# Parse private key (hex string → int)
priv_hex = sys.argv[1].strip().lower()
if priv_hex.startswith("0x"):
    priv_hex = priv_hex[2:]
priv_int = int(priv_hex, 16)

# Build EC private key object (P-256 / secp256r1)
priv_key = ec.derive_private_key(priv_int, ec.SECP256R1())

# Get public key object
pub_key = priv_key.public_key()

# SEC1 uncompressed (0x04 || X || Y)
pub_uncompressed = pub_key.public_bytes(
    encoding=serialization.Encoding.X962,
    format=serialization.PublicFormat.UncompressedPoint
)

# SEC1 compressed (0x02/03 || X)
pub_compressed = pub_key.public_bytes(
    encoding=serialization.Encoding.X962,
    format=serialization.PublicFormat.CompressedPoint
)

print("Private key (hex):", priv_hex.rjust(64, "0"))
print("SEC1 uncompressed:", pub_uncompressed.hex())
print("SEC1 compressed  :", pub_compressed.hex())
