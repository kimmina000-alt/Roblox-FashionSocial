import subprocess,sys
from PIL import Image,ImageDraw
W='D:/Roblox/영상/_work/lemonade_full/'
SRC=[('R',W+'6RuwYynkefE.mp4',0.53),('B',W+'B8l_qT7j9pQ.mp4',0.58),('T',W+'TerTVKd7sVQ.mp4',None),('P','D:/Roblox/영상/aespa_Lemonade_NJx2IGeS8CQ.mp4',1.08)]
def ter(s):
    for a,b,o in [(0,86.2,0.17),(101.3,121.3,9.32),(130.3,179,12.27)]:
        if a<=s<b: return s-o
    return None
def frame(path,t,h=200):
    r=subprocess.run(['ffmpeg','-v','error','-ss','%.2f'%t,'-i',path,'-frames:v','1','-vf','scale=-1:%d'%h,'-f','image2pipe','-vcodec','png','-'],capture_output=True)
    from io import BytesIO
    return Image.open(BytesIO(r.stdout)) if r.stdout else None
a,b,step,name=float(sys.argv[1]),float(sys.argv[2]),float(sys.argv[3]),sys.argv[4]
cols=[a+i*step for i in range(int((b-a)/step)+1)]
rows=[]
for tag,p,off in SRC:
    row=[]
    for s in cols:
        t=(s+off) if off is not None else ter(s)
        im=frame(p,t) if t is not None and t>=0 else None
        if tag=='P' and im: im=im.crop((im.width//2-im.height*0.9,0,im.width//2+im.height*0.9,im.height))
        row.append(im)
    rows.append((tag,row))
cw=150
out=Image.new('RGB',(30+len(cols)*cw,len(rows)*200+20),'black'); d=ImageDraw.Draw(out)
for j,s in enumerate(cols): d.text((30+j*cw+2,2),'%.1f'%s,fill='yellow')
for i,(tag,row) in enumerate(rows):
    d.text((5,20+i*200+90),tag,fill='white')
    for j,im in enumerate(row):
        if im:
            im=im.resize((int(im.width*200/im.height),200)); x=(im.width-cw)//2
            im=im.crop((max(0,x),0,max(0,x)+cw,200))
            out.paste(im,(30+j*cw,20+i*200))
out.save(W+'sheets/cmp_%s.jpg'%name); print('ok',out.size)
