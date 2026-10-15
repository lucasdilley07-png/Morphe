#!/usr/bin/env python3
"""Cuts Lucas's loading art (BrandSource/loading-screen-source.webp) into the
LoadingPlate (waves, lettering + helmet painted out) and LoadingHelmet layers.
Run: python3 Tools/make_loading_layers.py <dir holding loading-src.webp>
then copy both PNGs into their imagesets as the -dark files and run make_launch_splash.py."""
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter
D=sys.argv[1]
src=Image.open(f'{D}/loading-src.webp').convert('RGB')
a=np.asarray(src).astype(np.float64)
H,W,_=a.shape
R,G=a[...,0],a[...,1]
def box(x,r):
    for axis in (0,1):
        c=np.cumsum(np.pad(x,[(r+1,r) if i==axis else (0,0) for i in range(x.ndim)],mode='edge'),axis=axis)
        n=x.shape[axis]; hi=[slice(None)]*x.ndim; lo=[slice(None)]*x.ndim
        hi[axis]=slice(2*r+1,2*r+1+n); lo[axis]=slice(0,n)
        x=(c[tuple(hi)]-c[tuple(lo)])/(2*r+1)
    return x
def gblur(x,r):
    for _ in range(3): x=box(x,max(1,r//2))
    return x
# --- helmet silhouette
win=np.zeros((H,W),np.uint8); win[355:1045,215:635]=1
seed=(((R>165)&(G>195))*win).astype(bool)
seed[:545,552:]=False          # the dotted ribbon crossing the crest's right fin
ys0,xs0=np.where(seed)
pts=sorted(set(zip(xs0[::7].tolist(),ys0[::7].tolist())))
def cross(o,a_,b_): return (a_[0]-o[0])*(b_[1]-o[1])-(a_[1]-o[1])*(b_[0]-o[0])
lo=[];up=[]
for q in pts:
    while len(lo)>=2 and cross(lo[-2],lo[-1],q)<=0: lo.pop()
    lo.append(q)
for q in reversed(pts):
    while len(up)>=2 and cross(up[-2],up[-1],q)<=0: up.pop()
    up.append(q)
hull=lo[:-1]+up[:-1]
him=Image.new('L',(W,H),0); ImageDraw.Draw(him).polygon(hull,fill=255)
solid=np.asarray(him).astype(np.uint8)
ys,xs=np.where(solid>0); print('helmet', xs.min(),xs.max(),ys.min(),ys.max())
hx0,hx1,hy0,hy1=xs.min(),xs.max(),ys.min(),ys.max()
# helmet layer: original pixels inside a generous feathered silhouette (keeps the glow)
hl=np.asarray(Image.fromarray(solid).filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(6))).astype(np.float64)/255
# --- hole for the plate: helmet + its glow + glow line + all baked text/bar
hole_img=Image.fromarray(solid).filter(ImageFilter.MaxFilter(71))
dr=ImageDraw.Draw(hole_img)
dr.rounded_rectangle((290,1022,560,1092),radius=24,fill=255)       # light bar under helmet
dr.rounded_rectangle((150,1078,725,1226),radius=34,fill=255)       # wordmark
dr.rounded_rectangle((215,1226,650,1280),radius=18,fill=255)       # tagline
dr.rounded_rectangle((190,1318,662,1382),radius=24,fill=255)       # bar
dr.rounded_rectangle((330,1376,532,1418),radius=14,fill=255)       # LOADING...
hard=np.asarray(hole_img).astype(np.float64)/255
known=(hard<0.5).astype(np.float64)
# push-pull: average known pixels down a pyramid, then fill holes from coarser levels
def down(x):
    h,w=x.shape[:2]; h2,w2=(h+1)//2,(w+1)//2
    p=np.zeros((h2*2,w2*2)+x.shape[2:]); p[:h,:w]=x
    return p.reshape(h2,2,w2,2,*x.shape[2:]).sum(axis=(1,3))
levels=[]; c=a*known[...,None]; wgt=known.copy()
while True:
    levels.append((c,wgt))
    if min(c.shape[:2])<=2: break
    c,wgt=down(c),down(wgt)
fillv=levels[-1][0]/np.maximum(levels[-1][1][...,None],1e-6)
for c,wgt in reversed(levels[:-1]):
    h,w=c.shape[:2]
    up=np.asarray(Image.fromarray(np.clip(fillv,0,255).astype(np.uint8)).resize((w,h),Image.BICUBIC)).astype(np.float64)
    own=c/np.maximum(wgt[...,None],1e-6)
    t=np.clip(wgt,0,1)[...,None]
    fillv=own*t+up*(1-t)
# soften the fill a touch so the pyramid never shows blocks
fill=np.stack([gblur(fillv[...,k],24) for k in range(3)],-1)
feather=np.asarray(hole_img.filter(ImageFilter.GaussianBlur(10))).astype(np.float64)/255
hole=np.maximum(hard,feather)
plate=a*(1-hole[...,None])+fill*hole[...,None]
# film-grain-level noise so the painted area matches the art's texture
rng=np.random.default_rng(7)
plate+=rng.normal(0,1.2,plate.shape)*hole[...,None]
Image.fromarray(np.clip(plate,0,255).astype(np.uint8)).save(f'{D}/LoadingPlate.png')
# helmet layer keyed: alpha = brightest channel (black -> clear), unpremultiplied colour
h=a*hl[...,None]
crop=(hx0-40,hy0-40,hx1+40,hy1+40)
hc=h[crop[1]:crop[3],crop[0]:crop[2]]
al=hc.max(2)
rgba=np.zeros(hc.shape[:2]+(4,))
rgba[...,:3]=np.clip(hc*255/np.maximum(al[...,None],1),0,255)
rgba[...,3]=al
Image.fromarray(rgba.astype(np.uint8)).save(f'{D}/LoadingHelmet.png')
print('helmet crop',crop,'size',(crop[2]-crop[0],crop[3]-crop[1]),'center',((crop[0]+crop[2])/2,(crop[1]+crop[3])/2))
