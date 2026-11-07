"""Generates assets/icon.png: orange square with 4 black lines (pure Python)."""
import struct
import sys
import zlib

N = 1024
ORANGE = (255, 138, 0)
BLACK = (0, 0, 0)
LINES = [  # (y, x1, x2) as fractions of N
    (0.28, 0.24, 0.76),
    (0.42, 0.24, 0.76),
    (0.56, 0.24, 0.76),
    (0.70, 0.24, 0.56),
]
R = 0.032 * N  # half thickness


def coverage(px, py, y, x1, x2):
    cx = min(max(px, x1), x2)
    d = ((px - cx) ** 2 + (py - y) ** 2) ** 0.5
    return min(max(R + 0.5 - d, 0.0), 1.0)


rows = []
for py in range(N):
    row = bytearray([0])
    cov = 0.0
    for ly, a, b in LINES:
        y = ly * N
        if abs(py - y) <= R + 2:
            row_cov = [coverage(px, py, y, a * N, b * N) for px in range(N)]
            break
    else:
        row_cov = None
    for px in range(N):
        c = 0.0
        if row_cov is not None:
            c = row_cov[px]
        r = int(ORANGE[0] * (1 - c) + BLACK[0] * c)
        g = int(ORANGE[1] * (1 - c) + BLACK[1] * c)
        bl = int(ORANGE[2] * (1 - c) + BLACK[2] * c)
        row += bytes((r, g, bl))
    rows.append(bytes(row))


def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
png += chunk(b"IEND", b"")

out = sys.argv[1] if len(sys.argv) > 1 else "assets/icon.png"
with open(out, "wb") as f:
    f.write(png)
print("wrote", out)
