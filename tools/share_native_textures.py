"""Reuse imported texture files when rebuilding the walkable GLB variants."""

import hashlib
import json
import os
import pathlib
import struct


ROOT = pathlib.Path(__file__).resolve().parents[1] / "game" / "downloaded"


def main():
    textures = {}
    for path in ROOT.rglob("*"):
        if path.suffix.lower() in {".png", ".jpg", ".jpeg"}:
            textures.setdefault(hashlib.sha256(path.read_bytes()).digest(), path)
    shared = 0
    remaining = 0
    for path in ROOT.glob("*_walkable.glb"):
        raw = path.read_bytes()
        magic, version, _ = struct.unpack_from("<4sII", raw)
        if magic != b"glTF" or version != 2:
            raise ValueError(f"Unsupported GLB: {path}")
        chunks = []
        offset = 12
        while offset < len(raw):
            size, kind = struct.unpack_from("<II", raw, offset)
            chunks.append((kind, raw[offset + 8 : offset + 8 + size]))
            offset += 8 + size
        document = json.loads(chunks[0][1])
        binary = next((data for kind, data in chunks if kind == 0x004E4942), b"")
        changed = False
        for image in document.get("images", []):
            if "bufferView" not in image:
                continue
            view = document["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            content = binary[start : start + view["byteLength"]]
            match = textures.get(hashlib.sha256(content).digest())
            if match is None:
                remaining += 1
                continue
            image["uri"] = os.path.relpath(match, path.parent).replace("\\", "/")
            image.pop("bufferView")
            image.pop("mimeType", None)
            shared += 1
            changed = True
        if changed:
            encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
            encoded += b" " * (-len(encoded) % 4)
            chunks[0] = (chunks[0][0], encoded)
            body = b"".join(struct.pack("<II", len(data), kind) + data for kind, data in chunks)
            path.write_bytes(struct.pack("<4sII", magic, version, len(body) + 12) + body)
    print("NATIVE_TEXTURES_SHARED", shared)
    print("NATIVE_TEXTURES_STILL_EMBEDDED", remaining)
    if remaining:
        raise SystemExit("Native rebuild contains unmatched embedded textures")


if __name__ == "__main__":
    main()
