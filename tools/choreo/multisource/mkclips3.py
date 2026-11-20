import json,sys,os,shutil,numpy as np,cv2
sys.path.insert(0,r'D:/Roblox/Roblox-FashionSocial/tools/choreo/centercut')
import centercut as cc
W='D:/Roblox/영상/_work/lemonade_full/'
def ter(s):
    for a,b,o in [(0,86.2,0.17),(101.3,121.3,9.32),(130.3,179,12.27)]:
        if a<=s<=b: return s-o
SRC={'R':(W+'6RuwYynkefE.mp4',W+'trk_6RuwYynkefE/tracks.json',lambda s:s+0.53),
     'B':(W+'B8l_qT7j9pQ.mp4',W+'trk_B8l_qT7j9pQ/tracks.json',lambda s:s+0.58),
     'T':(W+'TerTVKd7sVQ.mp4',W+'trk_TerTVKd7sVQ/tracks.json',ter),
     'P':(r'D:/Roblox/영상/aespa_Lemonade_NJx2IGeS8CQ.mp4',r'D:/Roblox/영상/aespa_Lemonade_v2_centercut/tracks.json',lambda s:s+1.08)}
# (n, src, song a, song b, reference song time for colour, keep-old-render dir or None)
CL=[(1,'R',5.0,12.0,10.0,'c01'),(2,'R',10.0,24.5,15.0,'c02'),(3,'B',22.5,37.0,34.0,'v4'),(4,'B',35.0,46.5,41.0,'v4'),
    (5,'B',44.5,59.0,50.0,'c05'),(6,'R',57.0,69.5,65.0,'c06'),(7,'R',67.5,82.0,75.0,'c07'),(8,'T',80.0,86.2,84.0,'v4'),
    (9,'P',84.5,95.5,90.0,'v4'),(10,'P',93.5,103.3,97.0,'v4'),(11,'T',101.3,115.5,108.0,'v4'),(12,'T',113.5,121.3,118.0,'v4'),
    (13,'R',119.5,127.0,121.0,None),(14,'P',125.5,135.0,128.0,None),(15,'T',133.5,145.5,140.0,None),(16,'B',143.5,151.0,146.0,'v4'),
    (17,'T',149.0,159.5,152.0,None),(18,'T',157.5,171.5,165.0,None),(19,'T',169.5,176.86,174.0,None)]
cache={}
def H(p): return cc.hist_of([p['hist']])
plan=[]
for n,s,a,b,ref,keep in CL:
    vid,trk,f=SRC[s]
    if trk not in cache:
        d=json.load(open(trk)); cache[trk]=(d,cc.stitch_ids(d['frames'],d['meta']['fps']))
    d,root=cache[trk]; fps=d['meta']['fps']; Wd,Hh=d['meta']['w'],d['meta']['h']
    va,vb=round(max(0.05,f(a)),2),round(f(b),2)
    entry={'n':n,'src':s,'video':vid,'song':[a,b],'video_span':[va,vb],'keep':keep}
    if keep: plan.append(entry); continue
    # reference: the most central large person at ref time
    fr=d['frames'][int(f(ref)*fps)]
    big=[p for p in fr if (p['box'][3]-p['box'][1])>0.3*Hh and p.get('hist')]
    r0=min(big,key=lambda p:abs((p['box'][0]+p['box'][2])/2-Wd/2)-0.5*(p['box'][3]-p['box'][1]))
    refh=H(r0)
    seeds=[]; t=va+0.2
    while t<vb-0.1:
        fr=d['frames'][min(len(d['frames'])-1,int(t*fps))]
        cand=[p for p in fr if p.get('hist') and (p['box'][3]-p['box'][1])>0.25*Hh and abs((p['box'][0]+p['box'][2])/2-Wd/2)<0.3*Wd]
        if cand:
            sc=[(cv2.compareHist(refh,H(p),cv2.HISTCMP_BHATTACHARYYA)+0.3*abs((p['box'][0]+p['box'][2])/2-Wd/2)/Wd,p) for p in cand]
            bst=min(sc,key=lambda x:x[0])
            if bst[0]<0.8: seeds.append([round(t,2),root.get(bst[1]['id'],bst[1]['id'])])
        t+=0.5
    out=W+'clips_v4/c%02d'%n
    os.makedirs(out,exist_ok=True)
    if not os.path.exists(out+'/tracks.json'): shutil.copy(trk,out+'/tracks.json')
    json.dump({'note':'lemonade v4 clip %d'%n,'cuts':[{'start':va,'end':vb,'id':seeds[0][1],'reason':'single dancer','seeds':seeds}]},open(out+'/cuts.json','w'))
    entry['seeds']=len(seeds); entry['ids']=sorted(set(x[1] for x in seeds)); plan.append(entry)
json.dump(plan,open(W+'clips_final_plan.json','w',encoding='utf-8'),indent=1)
for p in plan: print(p['n'],p['src'],p['song'],p['video_span'],p.get('keep'),p.get('seeds'),p.get('ids'))
