"""Runner-local process diagnostics, independent of the emulator's adb transport."""
import json,os,subprocess,sys,time
from pathlib import Path
with open('emulator.log','w') as out,open('emulator-status.jsonl','w',buffering=1) as status:
 p=subprocess.Popen(sys.argv[1:],stdout=out,stderr=subprocess.STDOUT)
 Path('emulator.pid').write_text(str(p.pid))
 start=time.monotonic()
 while True:
  state={'elapsed':round(time.monotonic()-start,1),'pid':p.pid,'exit':p.poll()}
  for key,path in [('memory','/proc/meminfo'),('cgroup_events','/sys/fs/cgroup/memory.events')]:
   try:state[key]=Path(path).read_text()
   except OSError:state[key]='unavailable'
  try:state['process']=Path(f'/proc/{p.pid}/status').read_text()
  except OSError:state['process']='absent'
  status.write(json.dumps(state)+'\n')
  if p.poll() is not None:break
  if time.monotonic()-start>600:p.terminate();state={'bounded_stop':True};status.write(json.dumps(state)+'\n');break
  time.sleep(5)
