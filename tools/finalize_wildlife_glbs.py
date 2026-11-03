"""Remove incompatible exported morph tracks; retain skeletal gait animation."""
import pathlib,json,struct
root=pathlib.Path(__file__).resolve().parents[1]/'game/animals/new'
for path in root.glob('*.glb'):
 if path.name in ['birds.glb','model_110a_-_imperial_woodpecker_flying.glb']:
  source=root.parents[2]/'source-assets/new-wildlife'/path.name
  # The birds use the original valid skeletal/morph flight tracks.
  source=pathlib.Path(__file__).resolve().parents[1]/'source-assets/new-wildlife'/path.name
  path.write_bytes(source.read_bytes());continue
 data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
 document=json.loads(data[20:20+length]);tail=data[20+length:]
 removed=0
 for animation in document.get('animations',[]):
  old=animation['channels'];animation['channels']=[c for c in old if c['target']['path']!='weights'];removed+=len(old)-len(animation['channels'])
 document['animations']=[a for a in document.get('animations',[]) if a['channels']]
 encoded=json.dumps(document,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
 output=struct.pack('<4sII',b'glTF',2,20+len(encoded)+len(tail))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+tail
 path.write_bytes(output)
 print(path.name,'morph_channels_removed',removed,'skeletal_clips',[a.get('name') for a in document.get('animations',[])])
