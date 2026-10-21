#!/usr/bin/env python3
"""Rebuild the five upstream FFmpeg payload libraries for 16 KB Android pages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import tarfile
import tempfile
import urllib.request

VERSION = '1.6.0'
URL = f'https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-{VERSION}.tar.gz'
SHA256 = 'e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564'
NAMES = ['libsharpyuv.so', 'libwebp.so', 'libwebpdecoder.so', 'libwebpdemux.so', 'libwebpmux.so']
ROOT = Path(__file__).resolve().parents[1]


def verify_elf(path):
    data = path.read_bytes()
    assert data[:6] == b'\x7fELF\x02\x01', f'Expected little-endian ELF64: {path}'
    offset = struct.unpack_from('<Q', data, 32)[0]
    entry_size, count = struct.unpack_from('<HH', data, 54)
    loads = []
    for index in range(count):
        kind, _, file_offset, address, _, _, _, alignment = struct.unpack_from('<IIQQQQQQ', data, offset + index * entry_size)
        if kind == 1:
            assert alignment >= 16384 and (address - file_offset) % 16384 == 0, f'Invalid 16 KB LOAD segment: {path}'
            loads.append(alignment)
    assert loads, f'No LOAD segments: {path}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', default=os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME'))
    parser.add_argument('--ndk-version', default='28.2.13676358')
    parser.add_argument('--cmake-version', default='3.22.1')
    args = parser.parse_args()
    if not args.sdk:
        parser.error('Pass --sdk /path/to/android/sdk or set ANDROID_SDK_ROOT')
    sdk = Path(args.sdk).resolve()
    ndk = sdk / 'ndk' / args.ndk_version
    host = 'darwin-x86_64' if platform.system() == 'Darwin' else 'linux-x86_64'
    strip = ndk / 'toolchains/llvm/prebuilt' / host / 'bin/llvm-strip'
    cmake = sdk / 'cmake' / args.cmake_version / 'bin/cmake'
    ninja = cmake.with_name('ninja')
    destination = ROOT / 'android/app/src/main/assets/native/arm64-v8a'
    with tempfile.TemporaryDirectory(prefix='oto-webp-build-') as temporary:
        folder = Path(temporary)
        archive = folder / 'source.tar.gz'
        archive.write_bytes(urllib.request.urlopen(URL, timeout=60).read())
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == SHA256, 'Source checksum mismatch'
        with tarfile.open(archive) as source:
            source.extractall(folder, filter='data')
        src, build = folder / f'libwebp-{VERSION}', folder / 'build'
        command = [str(cmake), '-S', str(src), '-B', str(build), '-G', 'Ninja',
                   f'-DCMAKE_MAKE_PROGRAM={ninja}', f'-DCMAKE_TOOLCHAIN_FILE={ndk}/build/cmake/android.toolchain.cmake',
                   '-DANDROID_ABI=arm64-v8a', '-DANDROID_PLATFORM=android-26', '-DCMAKE_BUILD_TYPE=Release',
                   '-DBUILD_SHARED_LIBS=ON', '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384',
                   '-DWEBP_BUILD_LIBWEBPMUX=ON']
        for option in ['CWEBP', 'DWEBP', 'GIF2WEBP', 'IMG2WEBP', 'VWEBP', 'WEBPINFO', 'WEBPMUX', 'ANIM_UTILS', 'EXTRAS']:
            command.append(f'-DWEBP_BUILD_{option}=OFF')
        subprocess.run(command, check=True)
        subprocess.run([str(cmake), '--build', str(build), '--parallel', '4'], check=True)
        destination.mkdir(parents=True, exist_ok=True)
        for name in NAMES:
            path = build / name
            subprocess.run([str(strip), '--strip-unneeded', str(path)], check=True)
            verify_elf(path)
            shutil.copy2(path, destination / name)
        notices = ROOT / 'android/app/src/main/assets/licenses'
        notices.mkdir(parents=True, exist_ok=True)
        for name in ['COPYING', 'PATENTS']:
            shutil.copy2(src / name, notices / f'libwebp-{name}')
    manifest = {
        'source': URL, 'sourceSha256': SHA256, 'ndk': args.ndk_version,
        'androidApi': 26, 'abi': 'arm64-v8a', 'pageSize': 16384,
        'libraries': {name: hashlib.sha256((destination / name).read_bytes()).hexdigest() for name in sorted(NAMES)},
    }
    (ROOT / 'tools/webp-build.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Installed five verified 16 KB ARM64 libraries from libwebp', VERSION)


if __name__ == '__main__':
    main()
