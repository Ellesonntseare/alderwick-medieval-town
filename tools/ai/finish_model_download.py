"""Resume the verified model download using bounded, validated HTTP ranges."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
from pathlib import Path
import shutil
import time
from urllib.request import Request, urlopen

ROOT=Path(__file__).resolve().parent
MODEL=ROOT/'models/qwen2.5-3b-instruct-q4_k_m.gguf'
SIZE=2104932768
SHA='626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d'
URL='https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/7dabda4d13d513e3e842b20f0d435c732f172cbe/qwen2.5-3b-instruct-q4_k_m.gguf'

def fetch(spec):
    index,start,end=spec
    path=MODEL.with_suffix('.range'+str(index))
    expected=end-start+1
    for attempt in range(4):
        existing=path.stat().st_size if path.exists() else 0
        if existing==expected:return path
        if existing>expected:raise RuntimeError('Unexpected oversized range')
        try:
            request=Request(URL+'?range='+str(start)+'-'+str(end)+'&attempt='+str(attempt),headers={'Range':f'bytes={start+existing}-{end}'})
            with urlopen(request,timeout=60) as response:
                content=response.headers.get('Content-Range','')
                if response.status!=206 or not content.startswith(f'bytes {start+existing}-{end}/'):
                    raise RuntimeError('Server did not honour the requested range: '+content)
                with path.open('ab') as output:
                    remaining=expected-existing
                    while remaining:
                        chunk=response.read(min(262144,remaining))
                        if not chunk:raise OSError('Range download ended early')
                        output.write(chunk)
                        remaining-=len(chunk)
            print('MODEL_RANGE_READY',index,expected,flush=True)
            return path
        except (OSError,TimeoutError) as error:
            print('MODEL_RANGE_RETRY',index,type(error).__name__,flush=True)
            time.sleep(1)
    raise RuntimeError('Range failed after retries')

if __name__=='__main__':
    prefix=MODEL.stat().st_size if MODEL.exists() else 0
    if prefix>SIZE:raise RuntimeError('Oversized model download')
    print('MODEL_RESUME prefix=',prefix,'remaining=',SIZE-prefix,flush=True)
    if prefix<SIZE:
        length=(SIZE-prefix+3)//4
        specs=[(i,prefix+i*length,min(SIZE-1,prefix+(i+1)*length-1)) for i in range(4) if prefix+i*length<SIZE]
        with ThreadPoolExecutor(max_workers=4) as pool:parts=list(pool.map(fetch,specs))
        with MODEL.open('ab') as output:
            for path in parts:
                with path.open('rb') as part:shutil.copyfileobj(part,output)
    digest=hashlib.file_digest(MODEL.open('rb'),'sha256').hexdigest()
    if digest!=SHA:raise RuntimeError('Model checksum mismatch')
    print('LOCAL_MODEL_VERIFIED bytes=',MODEL.stat().st_size,'sha256=',digest,flush=True)
