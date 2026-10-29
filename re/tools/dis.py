import sys
from skoolkit.snapshot import make_snapshot
from skoolkit.traceutils import disassemble
mem=make_snapshot(sys.argv[1],None)[0]
a=int(sys.argv[2],16); end=int(sys.argv[3],16)
while a<end:
    t,n=disassemble(mem,a,'$','02X','04X')
    print(f"{a:04X}  {' '.join(f'{mem[(a+i)&0xFFFF]:02X}' for i in range(n)):12} {t}")
    a+=n
