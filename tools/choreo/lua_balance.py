"""(D-1194) Brace balance of a Luau file, comments and strings left out: "final 0" = balanced. Run on ClubChoreo.lua before every commit
(a cut / replace that missed its end marker left code fragments behind twice in D-1192). python -P -E lua_balance.py <file>"""
import re,sys
src=open(sys.argv[1],encoding='utf-8').read()
out=[];i=0;n=len(src)
while i<n:
    c=src[i]
    if src.startswith('--',i):
        m=re.match(r'--\[(=*)\[',src[i:])
        if m:
            e=src.find(']'+m.group(1)+']',i); i=e+len(m.group(1))+2; continue
        e=src.find('\n',i); i=e if e>=0 else n; continue
    if c in '"\'':
        j=i+1
        while j<n and src[j]!=c:
            j+= 2 if src[j]=='\\' else 1
        out.append(' '*(j+1-i)); i=j+1; continue
    m=re.match(r'\[(=*)\[',src[i:])
    if m:
        e=src.find(']'+m.group(1)+']',i); i=e+len(m.group(1))+2; continue
    out.append(c); i+=1
s=''.join(out)
d=0;line=1;lines={}
for ch in s:
    if ch=='\n': line+=1
    elif ch=='{': d+=1
    elif ch=='}':
        d-=1
        if d<0: lines.setdefault(line,d)
print('final',d)
print([ (l,v) for l,v in lines.items()][:40])