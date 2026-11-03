from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'tools/inspect_downloaded_forest.py').read_text()
source=source.replace(r'C:\Users\elles\Downloads\a_forest_3_with_a_road_at_night_for_game.glb',r'C:\Users\elles\Desktop\chicken_shoot_gun_-_industrial_map.glb')
source=source.replace("root/'review/forest'","root/'review/neighbour-town'")
exec(compile(source,str(root/'tools/inspect_downloaded_forest.py'),'exec'))
