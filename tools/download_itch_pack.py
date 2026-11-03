import urllib.request,urllib.parse,http.cookiejar,re,json,pathlib,subprocess,zipfile,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
slug=sys.argv[1]
base='https://quaternius.itch.io/'+slug
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
s=op.open(base,timeout=25).read().decode();token=re.search(r'name="csrf_token" value="([^"]+)"',s).group(1)
r=json.load(op.open(urllib.request.Request(base+'/download_url',data=urllib.parse.urlencode({'csrf_token':token}).encode()),timeout=25))
s=op.open(r['url'],timeout=25).read().decode();token=re.search(r'name="csrf_token" value="([^"]+)"',s).group(1)
upload=re.search(r'data-upload_id="(\d+)"',s).group(1)
r=json.load(op.open(urllib.request.Request(base+'/file/'+upload+'?source=game_download&as_props=1',data=urllib.parse.urlencode({'csrf_token':token}).encode(),headers={'Referer':base,'X-Requested-With':'XMLHttpRequest'}),timeout=25))
path=ROOT/'source-assets'/(slug+'.zip')
subprocess.run(['curl.exe','-sS','-L','--fail','--max-time','180','-o',str(path),r['url']],check=True)
with zipfile.ZipFile(path) as z:
 assert z.testzip() is None
 z.extractall(ROOT/'source-assets'/slug)
 print('VERIFIED_PACK',slug,'files',len(z.namelist()),flush=True)
