import json,random,sys
seed=int(sys.argv[1]); frames=int(sys.argv[2]); random.seed(seed)
script=[[10,15,"SPACE"],[100,105,"2"],[200,205,"6"]]
f=300; keys=["1","Q","X","O","P","X 1","X O","X P","X Q","N","M","","SPACE","ENTER","6","X 1 O","Q X P"]
while f<frames:
    d=random.randint(5,300); k=random.choice(keys)
    if k in ("N","M","6","SPACE","ENTER"): d=random.randint(3,10)
    if k: script.append([f,f+d,k])
    f+=d+random.randint(0,20)
shots=list(range(0,frames,frames//24))
json.dump({"sna":"info.z80","frames":frames,"map":"map.txt","prefix":f"r{seed}","script":script,"shots":shots,"out":f"r{seed}.z80"},open(f"r{seed}.json","w"))
