"""Warm the local model before loading the full town; keep one test client alive."""
import json,os,pathlib,subprocess,sys,time
from urllib.request import urlopen
ROOT=pathlib.Path(__file__).resolve().parents[1]
log=(ROOT/'mission-ai-service-review.log').open('ab',buffering=0)
service=None
def health():
 try:
  with urlopen('http://127.0.0.1:34320/health?pid='+str(os.getpid()),timeout=3) as response:return json.load(response).get('ready',False)
 except OSError:return False
started=time.monotonic()
while not health():
 if service is None:service=subprocess.Popen([sys.executable,str(ROOT/'tools/ai/chat_server.py')],stdout=log,stderr=log,creationflags=0x08000000)
 if time.monotonic()-started>150:raise RuntimeError('AI prewarm did not finish')
 time.sleep(2)
print('MODEL_PREWARMED_BEFORE_WORLD',round(time.monotonic()-started,1),flush=True)
engine=ROOT/'tools/engine/Godot_v4.7.2-stable_win64_console.exe'
game=subprocess.Popen([str(engine),'--headless','--fixed-fps','60','--path',str(ROOT/'game'),'--script','res://adventure_builder_world_review.gd','--log-file',str(ROOT/'adventure-builder-world-final.log'),'--','--validate-adventure-builder-world','--no-voices'],cwd=ROOT,creationflags=0x08000000)
while game.poll() is None:health();time.sleep(2)
print('ADVENTURE_WORLD_PROCESS_EXIT',game.returncode,flush=True)
raise SystemExit(game.returncode)
