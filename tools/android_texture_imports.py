"""Configure or verify GPU texture imports in the independent Android project."""

import argparse
import re
from pathlib import Path

from PIL import Image


def configure(project, verify):
    count = 0
    for folder in ("assets", "animals", "characters", "downloaded", "kit"):
        for metadata in (project / folder).rglob("*.import"):
            source = metadata.with_suffix("")
            if source.suffix.lower() not in (".png", ".jpg", ".jpeg"):
                continue
            with Image.open(source) as image:
                if max(image.size) < 128:
                    continue
            settings = metadata.read_text(encoding="utf-8")
            if 'importer="texture"' not in settings:
                continue
            count += 1
            if verify:
                path = re.search(r'^path\.etc2="res://([^"]+)"$', settings, re.M)
                if ("compress/mode=2" not in settings or not path
                        or not (project / path[1]).is_file()):
                    raise ValueError(f"Missing Android ETC2 texture for {source}")
            else:
                updated, matches = re.subn(r"^compress/mode=\d+$", "compress/mode=2", settings, flags=re.M)
                if matches != 1:
                    raise ValueError(f"Missing texture compression setting in {metadata}")
                if updated != settings:
                    metadata.write_text(updated, encoding="utf-8")
    if not count:
        raise ValueError("Android staging contains no eligible imported 3D textures")
    print("Verified" if verify else "Configured", count, "Android 3D textures")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    configure(Path(__file__).resolve().parents[1] / "mobile-build/game", args.verify)
