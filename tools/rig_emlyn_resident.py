"""Fit the unused Emlyn source to the already verified town motion rig."""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
path = root / "tools" / "rig_new_characters.py"
source = path.read_text(encoding="utf-8")
original = next(line for line in source.splitlines() if line.startswith("CONFIG="))
replacement = "CONFIG=[('emlyn_-_game_character_design.glb','emlyn',[(.21,0,1.43),(.34,-.01,1.18),(.43,-.02,.99)])]"
source = source.replace(original, replacement, 1)
exec(compile(source, str(path), "exec"))
