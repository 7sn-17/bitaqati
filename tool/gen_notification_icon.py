
import struct, zlib, os

RES = 'android/app/src/main/res'
SIZES = [('mdpi', 24), ('hdpi', 36), ('xhdpi', 48), ('xxhdpi', 72), ('xxxhdpi', 96)]

def rounded(x, y, x0, y0, x1, y1, r):
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 - r

def write_rgba(path, size, data):
    raw = b''.join(b'\x00' + data[y * size * 4:(y + 1) * size * 4] for y in range(size))

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body +
                struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(png)

def glyph(size):
    """Two stacked cards, white on transparent.

    A notification icon is a mask: the system tints whatever is opaque, so it
    has to be a flat silhouette with no colour and no anti-aliased edges that
    would read as grey. Coverage is sampled 4x4 per pixel for clean curves.
    """
    px = bytearray(size * size * 4)
    gap = 2.0 / size
    for py in range(size):
        for pxx in range(size):
            hits = 0
            for sy in range(4):
                for sx in range(4):
                    x = (pxx + (sx + 0.5) / 4) / size
                    y = (py + (sy + 0.5) / 4) / size
                    back = rounded(x, y, 0.30, 0.12, 0.92, 0.60, 0.09) <= 0
                    clear = rounded(x, y, 0.06 - gap, 0.36 - gap, 0.74 + gap, 0.92 + gap, 0.11) <= 0
                    front = rounded(x, y, 0.06, 0.36, 0.74, 0.92, 0.10) <= 0
                    if front or (back and not clear):
                        hits += 1
            a = int(255 * hits / 16)
            o = (py * size + pxx) * 4
            px[o] = 255
            px[o + 1] = 255
            px[o + 2] = 255
            px[o + 3] = a
    return bytes(px)

for bucket, size in SIZES:
    write_rgba('%s/drawable-%s/ic_notification.png' % (RES, bucket), size, glyph(size))
print('notification icon written')
