#!/usr/bin/env python3
import sys
import base64
import struct

def read_string(data, offset):
    """Read a length-prefixed string from SSH encoding"""
    l = struct.unpack(">I", data[offset:offset+4])[0]
    offset += 4
    s = data[offset:offset+l]
    offset += l
    return s, offset

def extract_public_key_bytes(pubkey_file):
    with open(pubkey_file, "r") as f:
        parts = f.read().strip().split()
        if len(parts) < 2:
            raise ValueError("Invalid OpenSSH public key format")
        key_type, key_b64 = parts[0], parts[1]
        if key_type != "ecdsa-sha2-nistp256":
            raise ValueError(f"Unsupported key type: {key_type}")

    raw = base64.b64decode(key_b64)

    # SSH format: string keytype, string curve, string Q (the public key point)
    offset = 0
    keytype, offset = read_string(raw, offset)
    curve, offset = read_string(raw, offset)
    q, offset = read_string(raw, offset)

    if keytype != b"ecdsa-sha2-nistp256" or curve != b"nistp256":
        raise ValueError("Not a nistp256 ECDSA key")

    if len(q) != 65 or q[0] != 0x04:
        raise ValueError("Unexpected EC point format")

    return q  # 65 bytes

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <ssh-ecdsa-pubkey-file>")
        sys.exit(1)

    pub_bytes = extract_public_key_bytes(sys.argv[1])
    print(pub_bytes.hex())
    # or raw bytes if you prefer:
    # sys.stdout.buffer.write(pub_bytes)
