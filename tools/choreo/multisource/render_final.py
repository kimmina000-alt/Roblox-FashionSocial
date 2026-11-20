import json,subprocess,sys,os
W='D:/Roblox/영상/_work/lemonade_full/'
CC=r'D:/Roblox/Roblox-FashionSocial/tools/choreo/centercut/'
only=[int(x) for x in sys.argv[1:]]
for p in json.load(open(W+'clips_final_plan.json',encoding='utf-8')):
    if only and p['n'] not in only: continue
    if p.get('keep'): continue
    d=W+'clips_v4/c%02d'%p['n']
    with open(d+'/log.txt','w',encoding='utf-8') as lf:
        r=subprocess.run([CC+'.venv/Scripts/python.exe',CC+'centercut.py',p['video'],'--out',d,'--keep-cuts','--blur','--no-beats','--scene','1.1'],stdout=lf,stderr=subprocess.STDOUT)
    print('clip',p['n'],'rc',r.returncode,os.listdir(d+'/clips') if os.path.isdir(d+'/clips') else None,flush=True)
