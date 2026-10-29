"""Recursive-descent code discovery seeded by runtime map + known entries. Writes a SkoolKit ctl."""
import sys, re
from skoolkit.snapshot import make_snapshot
from skoolkit.traceutils import disassemble
mem = make_snapshot(sys.argv[1], None)[0]
seeds = [int(l.strip()[1:], 16) for l in open(sys.argv[2]) if int(l.strip()[1:], 16) >= 0x5B00]
extra = [int(x, 16) for x in sys.argv[3].split(',')] if len(sys.argv) > 3 and sys.argv[3] else []
code = {}      # addr -> (len, text)
calls = set(extra) | {0xE280, 0xF74E, 0x83C2, 0x5EEC, 0x5B00}
work = list(calls) + seeds
jt = set()
while work:
    a = work.pop()
    while a not in code and 0x5B00 <= a <= 0xFFFF:
        t, n = disassemble(mem, a, '$', '02X', '04X')
        code[a] = (n, t)
        op = t.split()[0] if t else ''
        m = re.search(r'\$([0-9A-F]{4})$', t)
        tgt = int(m.group(1), 16) if m else None
        if op in ('JP', 'JR', 'DJNZ', 'CALL') and tgt is not None and ',' not in t.replace(f',${m.group(1)}','') or (op in ('JP','JR','CALL') and tgt is not None):
            if op == 'CALL' or op in ('JP','JR','DJNZ'):
                if tgt >= 0x5B00: work.append(tgt)
                if op == 'CALL': calls.add(tgt)
        if op == 'RST':
            pass
        uncond = (op in ('JP', 'JR') and ',' not in t) or t in ('RET', 'RETI', 'RETN') or t.startswith('JP (')
        if t.startswith('JP ('): jt.add(a)
        if uncond: break
        a += n
# write ctl: code addresses ranges; block starts at call targets/entries
addrs = sorted(code)
covered = set()
for a in addrs:
    for i in range(code[a][0]): covered.add(a + i)
print(f'code instructions: {len(code)}, bytes {len(covered)}', file=sys.stderr)
print('indirect jumps at', ' '.join(f'{x:04X}' for x in sorted(jt)), file=sys.stderr)
print("calls",len(calls),file=sys.stderr)
starts = set(calls) | {a for a in addrs if a - 1 not in covered}
out = []
a = 0x5B00
while a <= 0xFFFF:
    if a in covered:
        if a in starts or not out or out[-1][0] != 'c':
            out.append(['c', a])
        a += code[a][0] if a in code else 1
    else:
        if not out or out[-1][0] != 'b':
            out.append(['b', a])
        a += 1
with open(sys.argv[4] if len(sys.argv) > 4 else 'rd.ctl', 'w') as f:
    for k, a in out:
        f.write(f'{k} ${a:04X}\n')
    f.write('i $10000\n')
