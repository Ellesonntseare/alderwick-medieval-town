import pathlib,json,subprocess,concurrent.futures
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'source-assets'/'quaternius-animals'
OUT.mkdir(exist_ok=True)
items=json.loads((ROOT/'source-assets'/'animal-files.json').read_text())
names={'Cow','Horse','Donkey','ShibaInu','Deer'}
def fetch(item):
 id,title=item
 name=title.split('.')[0]
 if name not in names:return
 path=OUT/(name+'.gltf')
 if not path.exists():
  subprocess.run(['curl.exe','-sS','-L','--fail','--max-time','120','--retry','2','-o',str(path),'https://drive.usercontent.google.com/download?id='+id+'&export=download'],check=True)
 data=path.read_bytes()
 if data[:4]==b'glTF':
  dest=ROOT/'game'/'animals'/(name+'.glb')
 else:
  model=json.loads(data)
  assert model.get('meshes') and model.get('animations')
  assert all(b.get('uri','').startswith('data:') for b in model.get('buffers',[])), 'External buffer needs downloading'
  dest=ROOT/'game'/'animals'/(name+'.gltf')
 dest.parent.mkdir(exist_ok=True)
 dest.write_bytes(data)
 print('ANIMAL_DOWNLOADED',name,len(data),dest.name,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:list(pool.map(fetch,items))
(OUT/'SOURCE.md').write_text('Quaternius Ultimate Animated Animal Pack\nhttps://quaternius.com/packs/ultimateanimatedanimals.html\nCC0 as declared on the creator pack page. Files fetched from the creator-linked public glTF folder.\n')
