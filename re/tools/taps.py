import sys,os
data=open(sys.argv[1],'rb').read(); out=sys.argv[2]; os.makedirs(out,exist_ok=True)
i=0;n=0
while i<len(data):
    l=data[i]|data[i+1]<<8; blk=data[i+2:i+2+l]; i+=2+l; n+=1
    open(f"{out}/blk{n}.bin",'wb').write(blk[1:-1])
    print(n,l,blk[0])
