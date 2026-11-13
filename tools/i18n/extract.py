"""Collect every Korean UI string in src/ (and extra Lua files) for the translation tables.

Usage: python tools/i18n/extract.py [extra.lua ...]
Writes tools/i18n/strings.tsv: kind \t key \t uses \t first file:line

kind = exact   : a whole string literal, shown as is
       tmpl    : a string.format() pattern or a "a" .. x .. "b" chain; {1} {2} mark the values

Literals that are only logs (print / warn / error / assert), instance names
(FindFirstChild / WaitForChild / attributes) or table keys are left out.
Keep this file in step with the runtime matcher (src/.../Shared/L.lua).
"""
import os, re, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HANGUL = re.compile(r'[\uac00-\ud7a3]')

def lex(src):
    """Very small Lua lexer: yields (type, value, line). Strings keep their decoded value."""
    i, n, line = 0, len(src), 1
    toks = []
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1; i += 1; continue
        if c in ' \t\r':
            i += 1; continue
        if src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = src.find('\n', i)
                j = n if j < 0 else j
            line += src.count('\n', i, j); i = j; continue
        m = re.match(r'\[(=*)\[', src[i:])
        if m:
            close = ']' + m.group(1) + ']'
            j = src.find(close, i)
            body = src[i + len(m.group(0)):j]
            if body.startswith('\n'): body = body[1:]
            toks.append(('str', body, line))
            line += src.count('\n', i, j); i = j + len(close); continue
        if c in '"\'':
            j = i + 1; out = []
            while j < n and src[j] != c:
                if src[j] == '\\':
                    e = src[j + 1]
                    if e == 'n': out.append('\n'); j += 2
                    elif e == 't': out.append('\t'); j += 2
                    elif e in '"\'\\': out.append(e); j += 2
                    elif e.isdigit():
                        m2 = re.match(r'\d{1,3}', src[j + 1:])
                        out.append(chr(int(m2.group(0)))); j += 1 + len(m2.group(0))
                    elif e == 'u':
                        m2 = re.match(r'u\{([0-9a-fA-F]+)\}', src[j + 1:])
                        out.append(chr(int(m2.group(1), 16))); j += 1 + len(m2.group(0))
                    elif e == 'x':
                        out.append(chr(int(src[j + 2:j + 4], 16))); j += 4
                    elif e == '\n': out.append('\n'); line += 1; j += 2
                    else: out.append(e); j += 2
                else:
                    if src[j] == '\n': line += 1
                    out.append(src[j]); j += 1
            toks.append(('str', ''.join(out), line)); i = j + 1; continue
        if c == '`':  # interpolated string: treat {expr} as a value
            j = i + 1; out = []; k = 0
            while j < n and src[j] != '`':
                if src[j] == '\\':
                    out.append(src[j + 1]); j += 2; continue
                if src[j] == '{':
                    d = 1; j += 1
                    while j < n and d:
                        if src[j] == '{': d += 1
                        elif src[j] == '}': d -= 1
                        j += 1
                    k += 1; out.append('\x00'); continue
                out.append(src[j]); j += 1
            toks.append(('istr', ''.join(out), line)); i = j + 1; continue
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i:])
        if m:
            toks.append(('name', m.group(0), line)); i += len(m.group(0)); continue
        m = re.match(r'0[xX][0-9a-fA-F_]+|\d[\d_]*(\.\d*)?([eE][+-]?\d+)?|\.\d+', src[i:])
        if m:
            toks.append(('num', m.group(0), line)); i += len(m.group(0)); continue
        for op in ('...', '..=', '..', '==', '~=', '<=', '>=', '//', '::', '->', '+=', '-=', '*=', '/='):
            if src.startswith(op, i):
                toks.append(('op', op, line)); i += len(op); break
        else:
            toks.append(('op', c, line)); i += 1
    return toks

FMT = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgxXqc]')
SKIP_CALLS = {'print', 'warn', 'error', 'assert', 'FindFirstChild', 'WaitForChild', 'FindFirstChildOfClass',
              'GetAttribute', 'SetAttribute', 'FindFirstAncestor', 'GetAttributeChangedSignal', 'require'}
# table fields that hold notes, not shown text
SKIP_FIELDS = {'look', 'key', 'note', 'notes'}
KEYWORDS_SEP = {'then', 'do', 'return', 'local', 'if', 'elseif', 'else', 'end', 'and', 'or', 'not',
                'while', 'for', 'in', 'function', 'until', 'repeat'}

def norm(s):
    return s

def fmt_to_tmpl(s):
    k = [0]
    def rep(m):
        if m.group(0) == '%%': return '%'
        k[0] += 1; return '{%d}' % k[0]
    return re.sub(r'%%|' + FMT.pattern, rep, s)

def analyse(path, rel, found):
    src = open(path, encoding='utf-8').read()
    toks = lex(src)
    n = len(toks)
    used = set()

    def callee_before(idx):
        # literal at idx directly inside f( ... ) or f"..."
        j = idx - 1
        if j >= 0 and toks[j] == ('op', '(', toks[j][2]) or (j >= 0 and toks[j][0] == 'op' and toks[j][1] == '('):
            if j - 1 >= 0 and toks[j - 1][0] == 'name':
                return toks[j - 1][1]
        if j >= 0 and toks[j][0] == 'name':
            return toks[j][1]
        return None

    def enclosing_call(idx):
        d = 0; j = idx - 1
        while j >= 0:
            t = toks[j]
            if t[0] == 'op' and t[1] in ')]}': d += 1
            elif t[0] == 'op' and t[1] in '([{':
                if d == 0:
                    if t[1] == '(' and j - 1 >= 0 and toks[j - 1][0] == 'name':
                        return toks[j - 1][1]
                    return None
                d -= 1
            j -= 1
        return None

    # concat chains
    def operand_end(j):
        """from token j, skip one operand forward, return index after it"""
        d = 0
        while j < n:
            t = toks[j]
            if t[0] == 'op' and t[1] in '([{': d += 1
            elif t[0] == 'op' and t[1] in ')]}':
                if d == 0: return j
                d -= 1
            elif d == 0:
                if t[0] == 'op' and t[1] in ('..', ',', '=', ';', '==', '~=', '<', '>', '<=', '>=', '+', '-', '*', '/', '..='):
                    return j
                if t[0] == 'name' and t[1] in KEYWORDS_SEP: return j
                # a new statement: name right after a closing ) or name or str at depth 0
                if j > 0 and t[0] in ('name', 'str', 'num') and toks[j - 1][0] in ('name', 'str', 'num') and toks[j - 1][1] not in ('.', ':'):
                    return j
                if t[0] == 'name' and j > 0 and toks[j - 1][0] == 'op' and toks[j - 1][1] == ')':
                    return j
            j += 1
        return j

    def operand_start(j):
        """token j is the last token of an operand; walk back to its first token"""
        d = 0
        while j >= 0:
            t = toks[j]
            if t[0] == 'op' and t[1] in ')]}': d += 1
            elif t[0] == 'op' and t[1] in '([{':
                if d == 0: return j + 1
                d -= 1
                if d == 0:
                    # call or index: continue to its callee
                    if j - 1 >= 0 and (toks[j - 1][0] in ('name',) or toks[j - 1][1] in (')', ']')):
                        j -= 1; continue
                    return j
            elif d == 0:
                if t[0] == 'op' and t[1] in ('.', ':'):
                    j -= 1; continue
                if t[0] in ('name', 'str', 'num', 'istr'):
                    if t[0] == 'name' and t[1] in KEYWORDS_SEP: return j + 1
                    if j - 1 >= 0 and toks[j - 1][0] == 'op' and toks[j - 1][1] in ('.', ':'):
                        j -= 1; continue
                    if j - 1 >= 0 and toks[j - 1][0] == 'op' and toks[j - 1][1] == '#':
                        return j - 1
                    return j
                return j + 1
            j -= 1
        return 0

    i = 0
    while i < n:
        t = toks[i]
        if t[0] in ('str', 'istr') and HANGUL.search(t[1]) and i not in used:
            # find the chain around it
            # walk back over ".." operands
            start = operand_start(i)
            while start - 1 >= 0 and toks[start - 1][0] == 'op' and toks[start - 1][1] == '..':
                start = operand_start(start - 2)
            # walk forward
            ops = []
            j = start
            while True:
                e = operand_end(j)
                ops.append((j, e))
                if e < n and toks[e][0] == 'op' and toks[e][1] == '..':
                    j = e + 1; continue
                break
            call = enclosing_call(start)
            prev = toks[start - 1] if start > 0 else None
            nxt = toks[ops[-1][1]] if ops[-1][1] < n else None
            is_key = (prev and prev[1] == '[' and nxt and nxt[1] == ']' ) or (nxt and nxt[1] == '=' and prev and prev[1] in ('{', ',', ';'))
            field = toks[start - 2][1] if start >= 2 and prev and prev[1] == '=' and toks[start - 2][0] == 'name' else None
            if call in SKIP_CALLS or is_key or field in SKIP_FIELDS:
                for a, b in ops:
                    for k in range(a, b): used.add(k)
                i += 1; continue
            if len(ops) > 1:
                parts = []; vals = 0; has = False
                for a, b in ops:
                    if b - a == 1 and toks[a][0] == 'str':
                        parts.append(fmt_to_tmpl(toks[a][1]) if FMT.search(toks[a][1]) else toks[a][1].replace('%%', '%'))
                        used.add(a)
                        if HANGUL.search(toks[a][1]): has = True
                    else:
                        vals += 1; parts.append('{%d}' % vals)
                # renumber placeholders in order
                s = ''.join(parts); k = [0]
                s = re.sub(r'\{\d+\}', lambda m: (k.__setitem__(0, k[0] + 1), '{%d}' % k[0])[1], s)
                if has:
                    found[('tmpl', s)].append('%s:%d' % (rel, t[2]))
                # also keep each Korean literal piece on its own (it may be shown alone)
                i += 1; continue
            s = t[1]
            if t[0] == 'istr':
                k = [0]
                s = re.sub('\x00', lambda m: (k.__setitem__(0, k[0] + 1), '{%d}' % k[0])[1], s)
                found[('tmpl', s)].append('%s:%d' % (rel, t[2]))
            elif FMT.search(s) or '%%' in s:
                found[('tmpl', fmt_to_tmpl(s))].append('%s:%d' % (rel, t[2]))
            else:
                found[('exact', s)].append('%s:%d' % (rel, t[2]))
        i += 1

# not shown to players (logs / owner analytics) or never translated (song titles, choreo / camera data)
SKIP_FILES = {'L.lua', 'Analytics.lua', 'ZoneAnalyticsService.lua', 'ClubPlaylist.lua', 'ClubChoreo.lua',
              'ClubCamera.lua', 'JoinedSongPlayer.lua'}

def sid(s):
    # stable id from the Korean text (same as tools/i18n/build.py)
    h = 0
    for b in s.encode('utf-8'):
        h = (h * 31 + b) % 2147483647
    return '%06x' % (h % 0xffffff)

def main():
    found = collections.defaultdict(list)
    files = []
    for base in ('src',):
        for dp, dn, fn in os.walk(os.path.join(ROOT, base)):
            for f in fn:
                if f.endswith('.lua'): files.append(os.path.join(dp, f))
    files += sys.argv[1:]
    # texts that live only in the place (signs, prompts): one per line, kind exact
    world = os.path.join(ROOT, 'tools', 'i18n', 'world_texts.txt')
    if os.path.exists(world):
        for ln in open(world, encoding='utf-8'):
            ln = ln.rstrip('\n')
            if ln and not ln.startswith('#'):
                found[('exact', ln.replace('\\n', '\n'))].append('place')
    extra = os.path.join(ROOT, 'tools', 'i18n', 'extra_templates.txt')
    if os.path.exists(extra):
        for ln in open(extra, encoding='utf-8'):
            ln = ln.rstrip('\n')
            if ln and not ln.startswith('#'):
                found[('tmpl', ln.replace('\\n', '\n'))].append('manual')
    for p in sorted(files):
        if os.path.basename(p) in SKIP_FILES or os.sep + 'I18n' + os.sep in p: continue
        analyse(p, os.path.relpath(p, ROOT).replace('\\', '/'), found)
    out = os.path.join(ROOT, 'tools', 'i18n', 'strings.tsv')
    def esc(s): return s.replace('\\', '\\\\').replace('\n', '\\n').replace('\t', '\\t')
    rows = sorted(found.items(), key=lambda kv: kv[1][0])
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        for (kind, s), where in rows:
            f.write('%s\t%s\t%s\t%d\t%s\n' % (sid(s), kind, esc(s), len(where), where[0]))
    c = collections.Counter(k for k, _ in found)
    print(len(found), dict(c), 'uses', sum(len(v) for v in found.values()))

if __name__ == '__main__':
    main()
