"""Resize embedded GLB images in the Android copy, preserving meshes and rigs."""
import io
import json
import struct
from pathlib import Path
from PIL import Image


def resize_glb(path: Path, limit: int = 512) -> int:
    raw = path.read_bytes()
    if len(raw) < 20 or struct.unpack_from('<III', raw) != (0x46546C67, 2, len(raw)):
        raise ValueError(f'Invalid GLB: {path.name}')
    chunks = []
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        chunks.append((kind, raw[offset:offset + size]))
        offset += size
    if len(chunks) != 2 or chunks[0][0] != 0x4E4F534A or chunks[1][0] != 0x004E4942:
        return 0
    data = json.loads(chunks[0][1])
    if len(data.get('buffers', [])) != 1 or data['buffers'][0].get('uri'):
        return 0
    replacements = {}
    for image in data.get('images', []):
        index = image.get('bufferView')
        if index is None or image.get('mimeType') not in ('image/png', 'image/jpeg'):
            continue
        view = data['bufferViews'][index]
        start = view.get('byteOffset', 0)
        with Image.open(io.BytesIO(chunks[1][1][start:start + view['byteLength']])) as picture:
            if max(picture.size) <= limit:
                continue
            picture.thumbnail((limit, limit), Image.Resampling.LANCZOS)
            output = io.BytesIO()
            if image['mimeType'] == 'image/jpeg':
                picture.convert('RGB').save(output, 'JPEG', quality=85)
            else:
                picture.save(output, 'PNG')
            replacements[index] = output.getvalue()
    if not replacements:
        return 0
    binary = bytearray()
    for index, view in enumerate(data.get('bufferViews', [])):
        if view.get('buffer', 0) != 0:
            raise ValueError(f'Unexpected external buffer: {path.name}')
        while len(binary) % 4:
            binary.append(0)
        start = view.get('byteOffset', 0)
        content = replacements.get(index, chunks[1][1][start:start + view['byteLength']])
        view['byteOffset'] = len(binary)
        view['byteLength'] = len(content)
        binary.extend(content)
    data['buffers'][0]['byteLength'] = len(binary)
    while len(binary) % 4:
        binary.append(0)
    metadata = json.dumps(data, separators=(',', ':')).encode()
    metadata += b' ' * (-len(metadata) % 4)
    total = 12 + 8 + len(metadata) + 8 + len(binary)
    path.write_bytes(struct.pack('<III', 0x46546C67, 2, total)
                     + struct.pack('<II', len(metadata), 0x4E4F534A) + metadata
                     + struct.pack('<II', len(binary), 0x004E4942) + binary)
    return len(replacements)
