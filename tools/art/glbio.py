import json, struct, math
def load(path):
    b=open(path,'rb').read()
    assert b[:4]==b'glTF'
    jl=struct.unpack('<I',b[12:16])[0]; js=json.loads(b[20:20+jl])
    off=20+jl; bl=struct.unpack('<I',b[off:off+4])[0]; binb=b[off+8:off+8+bl]
    return js,binb
def acc(js,binb,i):
    a=js['accessors'][i]; bv=js['bufferViews'][a['bufferView']]
    start=bv.get('byteOffset',0)+a.get('byteOffset',0)
    n=a['count']; t={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
    fmt={5126:'f',5123:'H',5125:'I'}[a['componentType']]
    sz=struct.calcsize(fmt)
    data=struct.unpack_from('<'+fmt*(n*t),binb,start)
    return [data[k*t:(k+1)*t] if t>1 else data[k] for k in range(n)]
def mesh(path):
    js,binb=load(path)
    pr=js['meshes'][0]['primitives'][0]
    P=acc(js,binb,pr['attributes']['POSITION']); N=acc(js,binb,pr['attributes']['NORMAL']); T=acc(js,binb,pr['attributes']['TEXCOORD_0']); I=acc(js,binb,pr['indices'])
    return P,N,T,[tuple(I[k:k+3]) for k in range(0,len(I),3)]
def write(path, parts):
    # parts: list of (name, P,N,T,tris, color)
    js={"asset":{"version":"2.0","generator":"split"},"scene":0,"scenes":[{"nodes":list(range(len(parts)))}],"nodes":[],"meshes":[],"materials":[],"accessors":[],"bufferViews":[],"buffers":[]}
    blob=bytearray()
    def addview(data,target):
        while len(blob)%4: blob.append(0)
        o=len(blob); blob.extend(data); js['bufferViews'].append({"buffer":0,"byteOffset":o,"byteLength":len(data),"target":target}); return len(js['bufferViews'])-1
    for pi,(name,P,N,T,tris,col) in enumerate(parts):
        used=sorted({v for t in tris for v in t}); remap={v:i for i,v in enumerate(used)}
        p=[P[v] for v in used]; n=[N[v] for v in used]; t=[T[v] for v in used]
        idx=[remap[v] for tr in tris for v in tr]
        vp=addview(struct.pack('<'+'f'*3*len(p),*[c for x in p for c in x]),34962)
        vn=addview(struct.pack('<'+'f'*3*len(n),*[c for x in n for c in x]),34962)
        vt=addview(struct.pack('<'+'f'*2*len(t),*[c for x in t for c in x]),34962)
        vi=addview(struct.pack('<'+'I'*len(idx),*idx),34963)
        mn=[min(x[k] for x in p) for k in range(3)]; mx=[max(x[k] for x in p) for k in range(3)]
        base=len(js['accessors'])
        js['accessors']+= [{"bufferView":vp,"componentType":5126,"count":len(p),"type":"VEC3","min":mn,"max":mx},{"bufferView":vn,"componentType":5126,"count":len(n),"type":"VEC3"},{"bufferView":vt,"componentType":5126,"count":len(t),"type":"VEC2"},{"bufferView":vi,"componentType":5125,"count":len(idx),"type":"SCALAR"}]
        js['materials'].append({"name":name+"_mat","pbrMetallicRoughness":{"baseColorFactor":list(col)+[1],"metallicFactor":0,"roughnessFactor":0.6},"doubleSided":True})
        js['meshes'].append({"name":name,"primitives":[{"attributes":{"POSITION":base,"NORMAL":base+1,"TEXCOORD_0":base+2},"indices":base+3,"material":pi}]})
        js['nodes'].append({"name":name,"mesh":pi})
    js['buffers']=[{"byteLength":len(blob)}]
    j=json.dumps(js,separators=(',',':')).encode()
    while len(j)%4: j+=b' '
    while len(blob)%4: blob.append(0)
    out=b'glTF'+struct.pack('<II',2,12+8+len(j)+8+len(blob))+struct.pack('<I',len(j))+b'JSON'+j+struct.pack('<I',len(blob))+b'BIN\x00'+bytes(blob)
    open(path,'wb').write(out)
