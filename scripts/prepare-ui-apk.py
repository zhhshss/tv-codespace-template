"""Disposable x86 UI fixture APK: remove ARM libraries and bypass unused Python loader."""
import hashlib, os, struct, sys, zipfile, zlib
from pathlib import Path

def patch_dex(blob, target, native):
    data = bytearray(blob)

    def u4(offset):
        return struct.unpack_from('<I', data, offset)[0]

    def u2(offset):
        return struct.unpack_from('<H', data, offset)[0]

    def leb(offset):
        value = shift = 0
        while True:
            byte = data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return (value, offset)
            shift += 7
    strings = []
    for i in range(u4(56)):
        _, offset = leb(u4(u4(60) + i * 4))
        end = data.index(0, offset)
        strings.append(data[offset:end].decode('utf-8', errors='replace'))
    types = [strings[u4(u4(68) + i * 4)] for i in range(u4(64))]
    if target not in types:
        return (blob, 0)
    methods = []
    for i in range(u4(88)):
        offset = u4(92) + i * 8
        methods.append((types[u2(offset)], strings[u4(offset + 4)]))
    count = 0
    for i in range(u4(96)):
        offset = u4(100) + i * 32
        if types[u4(offset)] != target:
            continue
        offset = u4(offset + 24)
        sf, offset = leb(offset)
        inf, offset = leb(offset)
        dm, offset = leb(offset)
        vm, offset = leb(offset)
        for _ in range(sf + inf):
            _, offset = leb(offset)
            _, offset = leb(offset)
        for section in (dm, vm):
            method_idx = 0
            for _ in range(section):
                diff, offset = leb(offset)
                method_idx += diff
                _, offset = leb(offset)
                code, offset = leb(offset)
                if methods[method_idx] != (target, '<init>'):
                    continue
                start = code + 16
                end = start + u4(code + 12) * 2
                print('UI-only loader patch:', target)
                new_offsets = [at for at in range(start, end - 3, 2) if data[at] == 34 and types[u2(at + 2)] == native]
                init_offsets = [at for at in range(start, end - 5, 2) if data[at] == 112 and methods[u2(at + 2)] == (native, '<init>')]
                assert len(new_offsets) == len(init_offsets) == 1, (new_offsets, init_offsets)
                at = new_offsets[0]
                reg = data[at + 1]
                assert reg < 16
                data[at:at + 4] = bytes([18, reg, 0, 0])
                at = init_offsets[0]
                data[at:at + 6] = bytes(6)
                count += 1
    if count:
        data[12:32] = hashlib.sha1(data[32:]).digest()
        struct.pack_into('<I', data, 8, zlib.adler32(data[12:]) & 4294967295)
    return (bytes(data), count)
if len(sys.argv) != 3:
    raise SystemExit('usage: prepare-ui-apk.py INPUT.apk OUTPUT-unsigned.apk')
source, target = sys.argv[1:3]
if Path(source).resolve() == Path(target).resolve():
    raise SystemExit('Input APK must be preserved; select a separate output path')
cache = Path(os.environ['GRADLE_USER_HOME']) / 'caches/modules-2/files-2.1'
if not cache.is_dir():
    raise SystemExit('Gradle dependency cache missing; build the ARM64 debug APK first')
x86_libraries = {}
for file in sorted(cache.rglob('*.aar')):
    with zipfile.ZipFile(file) as aar:
        for name in aar.namelist():
            if name.startswith('jni/x86_64/') and name.endswith('.so'):
                dest = name.replace('jni/', 'lib/', 1)
                data = aar.read(name)
                if dest in x86_libraries and x86_libraries[dest] != data:
                    raise SystemExit('Conflicting cached x86 libraries: ' + dest + '; use a dedicated GRADLE_USER_HOME')
                x86_libraries[dest] = data
if not x86_libraries:
    raise SystemExit('No x86_64 UI libraries found in the Gradle cache')
patched = 0
with zipfile.ZipFile(source) as inp, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as out:
    for info in inp.infolist():
        if info.filename.startswith('lib/') or (info.filename.startswith('META-INF/') and info.filename.upper().endswith(('.SF', '.RSA', '.DSA', '.MF'))):
            continue
        data = inp.read(info.filename)
        if info.filename.endswith('.dex'):
            for loader, native in [('PyLoader', 'com/fongmi/chaquo/Loader')]:
                data, count = patch_dex(data, 'Lcom/fongmi/android/tv/api/loader/' + loader + ';', 'L' + native + ';')
                patched += count
        out.writestr(info, data)
    for name, data in sorted(x86_libraries.items()):
        out.writestr(name, data, compress_type=zipfile.ZIP_STORED)
if patched != 1:
    Path(target).unlink(missing_ok=True)
    raise SystemExit(f'Unsupported TV bytecode; expected one Python loader patch, found {patched}')
print('Disposable UI APK prepared; Python/ARM playback paths excluded; cached x86 image and JS libs retained.')
