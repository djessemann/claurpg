import os,sys
ROOT="/home/user/claurpg"
# exec maps.py in a namespace to grab areas/NPCS/WARPS (it also rewrites mapdata.s identically)
ns={"__file__":os.path.join(ROOT,"tools","maps.py"),"__name__":"mapsmod"}
src=open(os.path.join(ROOT,"tools","maps.py")).read()
exec(compile(src,"maps.py","exec"),ns)
areas=ns["areas"]; NPCS=ns["NPCS"]; WARPS=ns["WARPS"]
COL={
 ".":"#23232f","o":"#30303f","g":"#3a3020","#":"#5c5c6e","L":"#5f83b8",
 "C":"#3f86c8","D":"#f2c14e","P":"#7a7a86","V":"#1a2a4a","*":"#0a0a16",
 "b":"#6f34a0","B":"#a740c8","H":"#c8331f","X":"#b0864a","T":"#37c0a0",
 "v":"#2c2c34","p":"#4a6fa8",
}
DLGSHORT={"DLG_WAKE":"AXIOM","DLG_VENDOR":"SHOP","DLG_REPAIR":"REPAIR","DLG_ENGINEER":"ENGR",
 "DLG_MEDIC":"MEDIC","DLG_SURVIVOR":"SURV","DLG_LOST":"LOST"}
CS=14  # cell size px
out={}
for i,a in enumerate(areas):
    w,h=a.w,a.h
    W,H=w*CS,h*CS
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" class="deckmap" shape-rendering="crispEdges">']
    svg.append(f'<rect width="{W}" height="{H}" fill="#0a0a12"/>')
    for y in range(h):
        for x in range(w):
            c=a.g[y][x]; col=COL.get(c,"#23232f")
            svg.append(f'<rect x="{x*CS}" y="{y*CS}" width="{CS}" height="{CS}" fill="{col}"/>')
    # grid lines subtle
    # warps
    for (x,y,dest,dx,dy) in WARPS.get(i,[]):
        svg.append(f'<rect x="{x*CS}" y="{y*CS}" width="{CS}" height="{CS}" fill="#f2c14e" stroke="#fff" stroke-width="1"/>')
        svg.append(f'<text x="{x*CS+CS/2}" y="{y*CS+CS-3}" font-size="9" fill="#000" text-anchor="middle" font-family="monospace">{dest}</text>')
    # npcs
    for (x,y,spr,pal,dlg) in NPCS.get(i,[]):
        svg.append(f'<circle cx="{x*CS+CS/2}" cy="{y*CS+CS/2}" r="{CS/2-1}" fill="#ff5a5a" stroke="#fff" stroke-width="1"/>')
    svg.append('</svg>')
    out[i]="".join(svg)
    open(os.path.join(sys.argv[1],f"map_{i}.svg"),"w").write(out[i])
print("maps:",list(out.keys()))
# confirm mapdata.s unchanged
