#!/usr/bin/env python3
import sys, binascii
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

def extract_private_key_hex(filename: str) -> str:
    with open(filename, "rb") as f:
        pem_data = f.read()
    key = serialization.load_pem_private_key(
        pem_data,
        password=None,
        backend=default_backend()
    )
    priv_bytes = key.private_numbers().private_value.to_bytes(32, "big")
    return binascii.hexlify(priv_bytes).decode()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <ec_private_key.pem>")
        sys.exit(1)

    print(extract_private_key_hex(sys.argv[1]))
