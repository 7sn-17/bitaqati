#!/usr/bin/env python3
"""Generates every launcher-icon resource the manifest references.

Why this exists instead of flutter_launcher_icons
-------------------------------------------------
That package writes the adaptive foreground to a fixed resource name
("ic_launcher_foreground") and the background colour to a fixed
("ic_launcher_background"), whatever "android:" name the config asks for.
Running it once per icon set therefore leaves the *last* set's artwork behind
all three mipmap-anydpi-v26 files: the crown, the blue icon and the default
one all render as whichever set was generated last. That is the bug this
script replaces the tool to fix.

The artwork is fixed, so the resources are generated once and committed
instead of rebuilt on every CI run. Nothing here needs the Flutter SDK.

Usage: python3 tool/gen_icons.py   (from the repository root)
"""

import os
import struct
import zlib

RES = 'android/app/src/main/res'

# Resource name -> artwork, background colour
SETS = [
    ('ic_launcher', 'default', (0x1A, 0x46, 0x32)),
    ('launcher_icon_crown', 'crown', (0x14, 0x66, 0x2A)),
    ('launcher_icon_blue', 'blue', (0x0F, 0x2C, 0x51)),
]

# Legacy square icon, in pixels of the launcher's density bucket.
MIPMAP = [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]

# Adaptive layers are 108dp: the launcher masks the middle 72dp.
DRAWABLE = [('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432)]

XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/{name}_background" />
    <foreground>
        <inset
            android:drawable="@drawable/{name}_foreground"
            android:inset="0%" />
    </foreground>
</adaptive-icon>
'''


def read_png(path):
    data = open(path, 'rb').read()
    i, idat, w, h, ct = 8, b'', None, None, None
    while i < len(data):
        length = struct.unpack('>I', data[i:i + 4])[0]
        kind = data[i + 4:i + 8]
        body = data[i + 8:i + 8 + length]
        i += 12 + length
        if kind == b'IHDR':
            w, h, _, ct, _, _, _ = struct.unpack('>IIBBBBB', body)
        elif kind == b'IDAT':
            idat += body
        elif kind == b'IEND':
            break
    raw = zlib.decompress(idat)
    ch = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
    stride = w * ch
    out = bytearray(w * h * ch)
    prev = bytearray(stride)
    pos = 0
    for y in range(h):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filt == 1:
            for x in range(ch, stride):
                line[x] = (line[x] + line[x - ch]) & 255
        elif filt == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif filt == 3:
            for x in range(stride):
                a = line[x - ch] if x >= ch else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif filt == 4:
            for x in range(stride):
                a = line[x - ch] if x >= ch else 0
                b = prev[x]
                c = prev[x - ch] if x >= ch else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, ch, out


def resize(w, h, ch, px, size):
    """Box filter: averages every source pixel that lands in a target cell."""
    out = bytearray(size * size * 3)
    for ty in range(size):
        y0, y1 = ty * h // size, max(ty * h // size + 1, (ty + 1) * h // size)
        for tx in range(size):
            x0, x1 = tx * w // size, max(tx * w // size + 1, (tx + 1) * w // size)
            r = g = b = n = 0
            for sy in range(y0, y1):
                base = sy * w
                for sx in range(x0, x1):
                    o = (base + sx) * ch
                    r += px[o]
                    g += px[o + 1]
                    b += px[o + 2]
                    n += 1
            q = (ty * size + tx) * 3
            out[q] = r // n
            out[q + 1] = g // n
            out[q + 2] = b // n
    return bytes(out)


def write_png(path, size, rgb):
    raw = b''.join(b'\x00' + rgb[y * size * 3:(y + 1) * size * 3] for y in range(size))

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body +
                struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(png)


def main():
    colours = {}
    for name, art, colour in SETS:
        w, h, ch, px = read_png('assets/app_icons/%s_adaptive.png' % art)
        for bucket, size in MIPMAP:
            write_png('%s/mipmap-%s/%s.png' % (RES, bucket, name),
                      size, resize(w, h, ch, px, size))
        for bucket, size in DRAWABLE:
            write_png('%s/drawable-%s/%s_foreground.png' % (RES, bucket, name),
                      size, resize(w, h, ch, px, size))
        xml = '%s/mipmap-anydpi-v26/%s.xml' % (RES, name)
        os.makedirs(os.path.dirname(xml), exist_ok=True)
        open(xml, 'w').write(XML.format(name=name))
        colours[name] = '#%02X%02X%02X' % colour

    # Merge the three background colours into the existing colors.xml rather
    # than rewriting it: launch_background lives there too.
    path = '%s/values/colors.xml' % RES
    body = open(path).read() if os.path.exists(path) else \
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n'
    for name, value in colours.items():
        if 'name="%s_background"' % name in body:
            continue
        body = body.replace('</resources>',
                            '    <color name="%s_background">%s</color>\n</resources>'
                            % (name, value))
    open(path, 'w').write(body)
    print('generated %d sets' % len(SETS))


if __name__ == '__main__':
    main()
