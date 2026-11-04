"""Check image resizing against a real rigged character, including buffer bytes."""
import io
import json
import pathlib
import shutil
import struct
from PIL import Image
from mobile_textures import resize_glb

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'game/characters/knight.glb'
target = root / 'review/mobile-texture-check.glb'
target.parent.mkdir(exist_ok=True)
shutil.copyfile(source, target)

def unpack(path):
    raw = path.read_bytes()
    size, _ = struct.unpack_from('<II', raw, 12)
    metadata = json.loads(raw[20:20 + size])
    binary_size, kind = struct.unpack_from('<II', raw, 20 + size)
    assert kind == 0x004E4942
    return metadata, raw[28 + size:28 + size + binary_size]

before, old = unpack(source)
count = resize_glb(target, 512)
after, new = unpack(target)
images = {image['bufferView'] for image in before.get('images', []) if 'bufferView' in image}
for key in ('accessors', 'animations', 'skins', 'meshes', 'nodes', 'scenes'):
    assert before.get(key) == after.get(key), key
for index, original in enumerate(before['bufferViews']):
    updated = after['bufferViews'][index]
    start, end = updated.get('byteOffset', 0), updated.get('byteOffset', 0) + updated['byteLength']
    assert start % 4 == 0 and end <= len(new)
    if index not in images:
        offset = original.get('byteOffset', 0)
        assert old[offset:offset + original['byteLength']] == new[start:end], index
    else:
        with Image.open(io.BytesIO(new[start:end])) as picture:
            assert max(picture.size) <= 512
assert count > 0 and target.stat().st_size < source.stat().st_size
print('MOBILE_TEXTURE_REVIEW_COMPLETE', count, 'images; original bytes', source.stat().st_size,
      'mobile bytes', target.stat().st_size, '; all geometry, skin, animation bytes unchanged')
