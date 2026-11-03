import concurrent.futures,pathlib,subprocess,zipfile,math
p=pathlib.Path(__file__).resolve().parent
archive=p/'godot-official.zip'
start=archive.stat().st_size
total=86013866
url='https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip'
parts=[]
step=math.ceil((total-start)/8)
for i,a in enumerate(range(start,total,step)):
    parts.append((a,min(total-1,a+step-1),p/f'engine-part-{i}.bin'))
def fetch(part):
    a,b,out=part
    subprocess.run(['curl.exe','-sS','-L','--fail','--max-time','600','--retry','2','-r',f'{a}-{b}','-o',str(out),url],check=True)
    assert out.stat().st_size==b-a+1
    print('Engine part ready',out.name,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: list(pool.map(fetch,parts))
with archive.open('ab') as dst:
    for a,b,out in parts:
        dst.write(out.read_bytes())
z=zipfile.ZipFile(archive)
assert z.testzip() is None
z.extractall(p/'engine')
print('GODOT_CRC_VERIFIED_AND_EXTRACTED',flush=True)
