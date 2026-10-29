import sys
from PIL import Image
files=sys.argv[2:]; ims=[Image.open(f) for f in files]
w,h=ims[0].size; cols=min(4,len(ims)); rows=(len(ims)+cols-1)//cols
m=Image.new('RGB',(w*cols,h*rows))
for i,im in enumerate(ims): m.paste(im,((i%cols)*w,(i//cols)*h))
m.save(sys.argv[1])
