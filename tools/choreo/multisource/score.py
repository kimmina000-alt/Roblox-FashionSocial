import json,sys,numpy as np
W='D:/Roblox/영상/_work/lemonade_full/'
def ter_map(t):
    # SBS 260531 Winter fancam: piecewise (chroma)
    if t<86: return t+0.17
    if 92<=t<112: return t+9.32
    if 118<=t<167: return t+12.27
    return None
MAPS={'TerTVKd7sVQ':ter_map,'6RuwYynkefE':lambda t:t-0.53,'B8l_qT7j9pQ':lambda t:t-0.58}
def score_source(name):
    d=json.load(open(W+'trk_'+name+'/tracks.json')); fps=d['meta']['fps']; Wd,H=d['meta']['w'],d['meta']['h']
    out={}
    prev=None
    for f,fr in enumerate(d['frames']):
        t=f/fps; s=MAPS[name](t)
        if s is None or s<0 or s>177: continue
        if not fr: out.setdefault(round(s*2)/2,[]).append(0); continue
        def pick(p):
            x0,y0,x1,y1=p['box']; cx=(x0+x1)/2; h=y1-y0
            return h/H - abs(cx-Wd/2)/Wd
        m=max(fr,key=pick); x0,y0,x1,y1=m['box']; kp=np.array(m['kp'])
        head=kp[0,2]>0.5 and y0>4
        feet=(kp[15,2]>0.4 or kp[16,2]>0.4) and y1<H-4
        occ=0
        for o in fr:
            if o is m: continue
            ox0,oy0,ox1,oy1=o['box']
            iw=max(0,min(x1,ox1)-max(x0,ox0)); ih=max(0,min(y1,oy1)-max(y0,oy0))
            if oy1>=y1-0.03*H: occ=max(occ,iw*ih/((x1-x0)*(y1-y0)))
        sc=(0.4 if head else 0)+(0.4 if feet else 0)+0.2*float((kp[:,2]>0.5).mean())
        sc*= (1-min(1,occ*1.5))
        out.setdefault(round(s*2)/2,[]).append(sc)
    return {k:float(np.mean(v)) for k,v in out.items()}
res={}
for n in sys.argv[1:]: res[n]=score_source(n)
json.dump(res,open(W+'scores.json','w'))
keys=sorted(set().union(*[set(v) for v in res.values()]))
for k in keys:
    print('%6.1f '%k+'  '.join('%s %.2f'%(n[:4],res[n].get(k,-1)) for n in res))
