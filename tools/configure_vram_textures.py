"""Configure GPU compression for 3D textures while preserving source images."""
import argparse
import json
import re
import struct
from pathlib import Path


def image_size(path):
    with path.open("rb") as image:
        header = image.read(24)
        if header.startswith(b"\x89PNG\r\n\x1a\n"):
            return struct.unpack(">II", header[16:24])
        if not header.startswith(b"\xff\xd8"):
            raise ValueError("Unsupported image format")
        image.seek(2)
        while True:
            marker = image.read(1)
            if not marker:
                raise ValueError("JPEG dimensions missing")
            if marker != b"\xff":
                continue
            marker = image.read(1)
            while marker == b"\xff":
                marker = image.read(1)
            if marker in (b"\x00", b"\xd8", b"\xd9"):
                continue
            length = struct.unpack(">H", image.read(2))[0]
            if marker in (b"\xc0", b"\xc1", b"\xc2", b"\xc3"):
                _, height, width = struct.unpack(">BHH", image.read(5))
                return width, height
            image.seek(length - 2, 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--scenery-limit", type=int, default=0)
    parser.add_argument("--all-3d-limit", type=int, default=0)
    options = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    game = root / "game"
    changes = {}
    pixels = 0
    resized_pixels = 0
    texture_limit = options.all_3d_limit or options.scenery_limit
    for directory in ("assets", "characters", "animals", "downloaded"):
        for metadata in (game / directory).rglob("*.import"):
            text = metadata.read_text(encoding="utf-8")
            if 'importer="texture"' not in text:
                continue
            relative = metadata.relative_to(game).as_posix()
            scenery = directory == "downloaded" and "/player-home/" not in relative and "/trade_items/" not in relative
            if texture_limit:
                if (not options.all_3d_limit and not scenery) or "compress/mode=2" not in text:
                    continue
            elif "compress/mode=0" not in text:
                continue
            source = Path(str(metadata)[:-7])
            try:
                width, height = image_size(source)
            except (OSError, ValueError):
                continue
            if max(width, height) < 128:
                continue
            limit = re.search(r"process/size_limit=(\d+)", text)
            maximum = int(limit.group(1)) if limit else 0
            if texture_limit:
                if not limit or max(width, height) <= texture_limit or 0 < maximum <= texture_limit:
                    continue
                new_ratio = min(1, texture_limit / max(width, height))
                resized_pixels += round(width * new_ratio) * round(height * new_ratio) * 4 / 3
            ratio = min(1, maximum / max(width, height)) if maximum else 1
            width = max(1, round(width * ratio))
            height = max(1, round(height * ratio))
            while True:
                pixels += width * height
                if "mipmaps/generate=true" not in text or max(width, height) == 1:
                    break
                width, height = max(1, width // 2), max(1, height // 2)
            changes[relative] = text
    report = {
        "texture_count": len(changes),
        "estimated_rgba_mib": round(pixels * 4 / 1048576, 1),
        "estimated_bc3_mib": round(pixels / 1048576, 1),
        "source_images_preserved": True,
        "resolution_limits_preserved": not texture_limit,
    }
    if texture_limit:
        report["estimated_scanned_scenery_savings_mib"] = round((pixels-resized_pixels)/1048576, 1)
    if options.apply:
        backup = root / "review" / "texture-import-backup.json"
        backup.parent.mkdir(exist_ok=True)
        existing = json.loads(backup.read_text(encoding="utf-8")) if backup.exists() else {}
        backup.write_text(json.dumps({**changes, **existing}, indent=2), encoding="utf-8")
        for relative, text in changes.items():
            metadata = game / relative
            if texture_limit:
                updated = re.sub(r"process/size_limit=\d+", f"process/size_limit={texture_limit}", text)
            else:
                updated = text.replace("compress/mode=0", "compress/mode=2")
            metadata.write_text(updated, encoding="utf-8")
        report_name = "low-memory-texture-report.json" if options.all_3d_limit else "scenery-texture-report.json" if options.scenery_limit else "texture-compression-report.json"
        (root / "review" / report_name).write_text(
            json.dumps(report, indent=2), encoding="utf-8"
        )
    print(json.dumps(report))


if __name__ == "__main__":
    main()
