import numpy as np,sys
def chroma(f):
    a=np.fromfile(f,dtype=np.int16).astype(float)
    hop=400; n=4096; w=np.hanning(n); fr=(len(a)-n)//hop
    freqs=np.fft.rfftfreq(n,1/8000); sel=(freqs>110)&(freqs<2000)
    pc=(np.round(12*np.log2(freqs[sel]/440))%12).astype(int)
    C=np.zeros((fr,12))
    for i in range(fr):
        s=np.abs(np.fft.rfft(a[i*hop:i*hop+n]*w))[sel]
        np.add.at(C[i],pc,s)
    C=np.log1p(C); C=C-C.mean(1,keepdims=True); C/= (np.linalg.norm(C,axis=1,keepdims=True)+1e-9)
    return C  # 20 Hz
o=chroma('ref8.raw'); np.save('ref_chroma.npy',o)
for f in sys.argv[1:]:
    r=chroma(f+'8.raw'); np.save(f+'_chroma.npy',r); win=160
    print('==',f)
    for st in range(0,len(r)-win,40):
        seg=r[st:st+win]; best=[]
        for k in range(0,len(o)-win):
            best.append(float((o[k:k+win]*seg).sum())/win)
        best=np.array(best); k=int(best.argmax()); b2=best.copy(); b2[max(0,k-20):k+20]=-9
        print('%6.1f  song %6.1f (song-stage %6.2f) score %.2f margin %.2f'%(st/20,k/20-1.08,k/20-1.08-st/20,best[k],best[k]-b2.max()))
