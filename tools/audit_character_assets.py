"""Record actual imported resident models and the remaining source figures."""
import json
import pathlib
import struct

root = pathlib.Path(__file__).resolve().parents[1]
downloads = pathlib.Path(r"C:\Users\elles\Downloads")
active = {
    "medieval": "All together / Medieval",
    "worker": "All together / Worker",
    "witch": "All together / Witch",
    "adventurer": "All together / Adventurer",
    "knight": "knight_with_spear_and_shield.glb",
    "mercenary": "blood_moor_mercenary_diablo_2_inspired_art.glb",
    "night_hunter": "night_hunter_assassin_-_dark_fantasy.glb",
    "viking": "gart220_female_viking.glb",
    "emlyn": "emlyn_-_game_character_design.glb",
}
remaining = {
    "saxon_warrior_-_t_pose.glb": "T pose; needs a fitted rig, walking clips and rigid shield mounting.",
    "bruce.glb": "Existing source skeleton; needs pose/deformation repair and motion retargeting.",
    "deadly_assassin_-_warrior_body_armor_weapons.glb": "Existing source skeleton; needs motion retargeting and equipment checks.",
    "medieval (1).glb": "Static figure; needs a fitted rig, garment weighting and walking clips.",
    "cult_member_enemy_character.glb": "Posed bow character; retained as source pending an appropriate training role or rigging.",
    "medieval.glb": "Static female figure; needs a fitted rig, garment weighting and walking clips.",
}

def metadata(path):
    if not path.is_file():
        return {}
    with path.open("rb") as file:
        header = file.read(12)
        if header[:4] != b"glTF":
            return {}
        size, kind = struct.unpack("<II", file.read(8))
        document = json.loads(file.read(size))
    return document.get("asset", {})

report = {"residents": 45, "active_base_models": [], "unused_figures": [], "outfit_pack": "Four male/female peasant/ranger outfits, plus modular parts; not assembled into additional complete animated residents."}
for model, source in active.items():
    path = root / "game" / "characters" / f"{model}.glb"
    report["active_base_models"].append({"model": model, "source": source, "installed": path.is_file(), "source_metadata": metadata(downloads / source)})
for source, reason in remaining.items():
    report["unused_figures"].append({"source": source, "available": (downloads/source).is_file(), "reason": reason, "source_metadata": metadata(downloads/source)})
report["training_display"] = {"source": "medieval_warrior.glb", "role": "Static training display, separate from the 45 walking residents."}
(root / "CHARACTER-ASSET-AUDIT.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
lines = ["# Character asset audit — 3 November 2026", "", "The town contains 45 named residents using nine base character models. Repeated base models still exist; spacing and different job locations reduce encounters with matching appearances. This is not a claim that all downloaded figures are animated residents.", "", "| Active base model | Source |", "|---|---|"]
for item in report["active_base_models"]:
    lines.append(f"| {item['model']} | {item['source']} |")
lines += ["", "Mina now uses the fitted Emlyn model. The names, stories and occupations of the 45 residents are retained.", "", "| Figure still outside the walking cast | Preparation needed |", "|---|---|"]
for source, reason in remaining.items():
    lines.append(f"| {source} | {reason} |")
lines += ["", report["outfit_pack"], "", report["training_display"]["role"], "", "Original downloads are preserved. Source author/license metadata extracted from the supplied GLBs is in `CHARACTER-ASSET-AUDIT.json`. The fitted Emlyn source is `source-assets/rigged-characters/emlyn.blend`; its runtime model is `game/characters/emlyn.glb`."]
(root / "CHARACTER-ASSET-AUDIT.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
print("CHARACTER_ASSET_AUDIT active=9 unused_figures=6 residents=45")
