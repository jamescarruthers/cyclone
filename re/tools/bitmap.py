import sys
from PIL import Image, ImageDraw
from skoolkit.snapshot import make_snapshot
mem=make_snapshot(sys.argv[1],None)[0]
s=int(sys.argv[2],16); e=int(sys.argv[3],16); colh=int(sys.argv[4]); w=int(sys.argv[5]) if len(sys.argv)>5 else 1
n=e-s; cols=(n+colh*w-1)//(colh*w); gap=4
img=Image.new('RGB',(cols*(8*w+gap),colh+12),(60,60,90)); px=img.load(); d=ImageDraw.Draw(img)
for c in range(cols):
    base=s+c*colh*w
    d.text((c*(8*w+gap),colh),f"{base:04X}"[:4],fill=(255,255,0))
    for y in range(colh):
        for b in range(w):
            a=base+y*w+b
            if a>=e: continue
            v=mem[a]
            for x in range(8):
                px[c*(8*w+gap)+b*8+x,y]=(0,0,0) if v&(0x80>>x) else (255,255,255)
img=img.resize((img.width*int(sys.argv[6] if len(sys.argv)>6 else 1), img.height*int(sys.argv[6] if len(sys.argv)>6 else 1)),Image.NEAREST)
img.save(sys.argv[7] if len(sys.argv)>7 else 'bm.png'); print(img.size)
