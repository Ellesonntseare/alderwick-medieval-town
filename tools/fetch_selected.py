"""Fetch selected CC0 pack files through HTTP byte ranges and verify their ZIP CRCs."""
import concurrent.futures, http.cookiejar, json, pathlib, re, struct, subprocess
import urllib.parse, urllib.request, zlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source-assets'
OUT = SOURCE / 'dungeon-selected'
BASE = 'https://algumacoisaqq.itch.io/medieval-village-dungeon-kit'
PREFIX = 'MedievalVillageKit_Godot/'
INDEX = {x['name'][len(PREFIX):]: x for x in json.loads((SOURCE/'remote-index.json').read_text())}

def signed_url():
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    s = op.open(BASE, timeout=20).read().decode()
    token = re.search(r'name="csrf_token" value="([^"]+)"', s).group(1)
    req = urllib.request.Request(BASE+'/file/20114925?source=game_download&as_props=1',
        data=urllib.parse.urlencode({'csrf_token':token}).encode(),
        headers={'Referer':BASE,'X-Requested-With':'XMLHttpRequest'})
    return json.load(op.open(req,timeout=20))['url']

def fetch(name, url):
    dest = OUT / name
    if dest.exists(): return dest
    item = INDEX[name]
    start = item['offset']
    # Name/extra lengths in a local ZIP header can extend beyond 30 bytes.
    end = start + item['compressed'] + len(item['name'].encode()) + 4096
    result = subprocess.run(['curl.exe','-sS','--fail','-L','--retry','2','--max-time','100',
        '-r',f'{start}-{end}',url],capture_output=True,check=True).stdout
    assert result[:4] == b'PK\x03\x04', name
    name_len, extra_len = struct.unpack_from('<HH',result,26)
    offset=30+name_len+extra_len
    data=result[offset:offset+item['compressed']]
    if item['method']==8: data=zlib.decompress(data,-15)
    assert len(data)==item['size'] and zlib.crc32(data)==item['crc'], name
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(data)
    print('Verified',name,len(data),flush=True)
    return dest

def main():
    pending=set(sys.argv[1:] or ['README.txt','LICENSE.txt','kit/structures/Chapel.tscn','kit/structures/Windmill.tscn','kit/structures/GuardTower.tscn'])
    seen=set()
    while pending:
        url=signed_url()
        batch=sorted(pending-seen)
        pending=set()
        if not batch: break
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
            paths=list(pool.map(lambda n: fetch(n,url),batch))
        seen.update(batch)
        for path in paths:
            if path.suffix in ('.tscn','.tres','.gdshader','.gdshaderinc'):
                text=path.read_text(encoding='utf-8-sig')
                for ref in re.findall(r'res://([^"\s)]+)',text):
                    if ref in INDEX and ref not in seen: pending.add(ref)
                # Shader #include references are also dependencies.
    (OUT/'fetched-manifest.json').write_text(json.dumps(sorted(seen),indent=2))
    print('SELECTED_ASSETS_READY',len(seen),flush=True)

if __name__=='__main__': main()
