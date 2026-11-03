import pathlib,json,shutil
R=pathlib.Path(__file__).resolve().parents[1]
inputs=R/'source-assets/wardrobe-inputs'
inputs.mkdir(exist_ok=True)
config=[]
for item in json.loads((R/'source-assets/assembled-outfits/outfit-fitting.json').read_text()):
 style=item['style'];shutil.copy2(R/'source-assets/assembled-outfits'/(style+'.glb'),inputs/(style+'.glb'))
 config.append((style+'.glb',style,item['arms']))
for style in ['runner_child','runner_youth']:
 shutil.copy2(R/'source-assets/medieval-runner-previews'/(style+'.glb'),inputs/(style+'.glb'))
 arm=[(.186,.042,1.286),(.430,.049,1.286),(.662,.042,1.286)] if style=='runner_child' else [(.20,.04,1.43),(.44,.05,1.43),(.67,.04,1.43)]
 config.append((style+'.glb',style,arm))
path=R/'tools/rig_new_characters.py'
source=path.read_text()
original=next(line for line in source.splitlines() if line.startswith('CONFIG='))
source=source.replace(original,'CONFIG='+repr(config),1)
source=source.replace("D=pathlib.Path(r'C:\\Users\\elles\\Downloads')",'D=pathlib.Path('+repr(str(inputs))+')')
source=source.replace("REPORT=json.loads((R/'rigged-character-report.json').read_text()) if ONLY else []","REPORT=json.loads((R/'rigged-character-report.json').read_text())")
source=source.replace("for side,sign in [('L',1),('R',-1)]:", """if style=='runner_child':
  for name,(head,tail) in list(points.items()):
   points[name]=((head[0],head[1],head[2]*.9),(tail[0],tail[1],tail[2] if name=='Head' else tail[2]*.9))
 for side,sign in [('L',1),('R',-1)]:""")
source=source.replace("Vector((.07*sign,0,1.39))", "Vector((.07*sign,0,1.251 if style=='runner_child' else 1.39))")
exec(compile(source,str(path),'exec'))
