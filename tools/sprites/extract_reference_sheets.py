"""
Cuts the individual sprites out of the original reference sheets in assets/sprites/source
and writes them to assets/sprites/parts/<Name>.png (transparent, tightly trimmed).

The crop boxes below are hand-placed for those four sheets. Rows of touching sprites are
split along a seam through the emptiest pixels. Only needed again if the source sheets change.

Usage (from the repo root):  python3 tools/sprites/extract_reference_sheets.py
Needs: pip install pillow numpy scipy
"""
import numpy as np, os
from PIL import Image
from scipy import ndimage
import pathlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
SRC=ROOT/"assets/sprites/source"
OUT=str(ROOT/"assets/sprites/parts"); os.makedirs(OUT, exist_ok=True)
FILES={"5":"bars_and_emotes.webp","6":"pets_eggs_rarity.webp","7":"upgrades_and_trucks.webp","8":"toppings.webp"}
sheets={k:np.array(Image.open(SRC/v).convert("RGBA")) for k,v in FILES.items()}

def seam(alpha, x_lo, x_hi):
    """Min-cost top-to-bottom path through columns x_lo..x_hi (cost = opacity)."""
    cost=(alpha[:, x_lo:x_hi].astype(np.float64)/255.0)
    h,w=cost.shape; acc=cost.copy(); back=np.zeros((h,w),dtype=np.int64)
    for y in range(1,h):
        prev=acc[y-1]
        left=np.r_[np.inf, prev[:-1]]; right=np.r_[prev[1:], np.inf]
        stack=np.vstack([left,prev,right]); idx=np.argmin(stack,axis=0)
        acc[y]+=stack[idx,np.arange(w)]; back[y]=idx-1
    x=int(np.argmin(acc[-1])); path=[0]*h
    for y in range(h-1,-1,-1):
        path[y]=x+x_lo; x=max(0,min(w-1,x+back[y][x]))
    return path

def split_row(sheet, y0, y1, x0, x1, cutcols, win=45):
    """Returns per-item masks (row-local) separated by seams near each cut column."""
    a=sheets[sheet][y0:y1,:,3]
    seams=[seam(a, c-win, c+win) for c in cutcols]
    bounds=[[x0]*(y1-y0)]+seams+[[x1]*(y1-y0)]
    items=[]
    for i in range(len(bounds)-1):
        L,R=bounds[i],bounds[i+1]
        items.append((L,R))
    return items

def save(name, sheet, y0, y1, x0, x1, colmask=None, pad=4):
    img=sheets[sheet][y0:y1, x0:x1].copy()
    if colmask:
        L,R=colmask
        for yy in range(img.shape[0]):
            l=L[yy]-x0; r=R[yy]-x0
            img[yy,:max(0,l),3]=0; img[yy,max(0,r):,3]=0
    # Drop small fragments of neighbouring sprites that touch the crop border.
    lab,n=ndimage.label(img[:,:,3]>8, structure=np.ones((3,3)))
    if n>1:
        areas=ndimage.sum(np.ones_like(lab),lab,range(1,n+1)); big=areas.max()
        edge=set(np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]))-{0}
        for i in edge:
            if areas[i-1]<0.2*big: img[lab==i,3]=0
    al=img[:,:,3]>8
    ys,xs=np.where(al)
    img=img[max(0,ys.min()-pad):ys.max()+pad+1, max(0,xs.min()-pad):xs.max()+pad+1]
    Image.fromarray(img).save(f"{OUT}/{name}.png")
    return img.shape[1], img.shape[0]

sizes={}
def S(name,*args,**kw): sizes[name]=save(name,*args,**kw)

# --- sheet 5: bars, emotes, dot
S("BarFrame","5",10,305,20,765)
S("BarFrameFilled","5",10,305,762,1500)
S("ComboBar","5",305,592,30,770)
S("PatienceBar","5",300,600,775,1495)
for (L,R),n in zip(split_row("5",585,895,5,1530,[308,598,900,1219]),["EmoteHappy","EmoteSad","EmoteAngry","EmoteThinking","EmoteLove"]):
    S(n,"5",585,895,5,1530,(L,R))
S("NotificationDot","5",870,1020,690,850)
# --- sheet 6: pets, eggs, rarity frames
pets=["PetPenguin","PetPolarBear","PetCow","PetConeCat","PetSprinkleDragon","PetMarshmallowGhost"]
for (L,R),n in zip(split_row("6",10,420,0,1536,[250,525,760,1005,1290]),pets):
    S(n,"6",10,420,0,1536,(L,R))
S("EggBasic","6",412,730,350,624)
S("EggRainbow","6",412,730,624,888)
S("EggLegendary","6",412,730,888,1215)
rar=["RarityCommon","RarityUncommon","RarityRare","RarityEpic","RarityLegendary","RarityMythic"]
for (L,R),n in zip(split_row("6",700,1000,0,1536,[262,514,767,1022,1276]),rar):
    S(n,"6",700,1000,0,1536,(L,R))
# --- sheet 7: upgrade icons, trucks
ic=["UpgradeMoveSpeed","UpgradeScoopSpeed","UpgradeServingCapacity","UpgradeStorage","UpgradeTipBonus"]
for (L,R),n in zip(split_row("7",40,332,10,1525,[328,615,918,1222]),ic):
    S(n,"7",40,332,10,1525,(L,R))
S("TruckPushcart","7",318,672,55,420)
S("TruckMiniVan","7",318,672,485,915)
S("TruckClassic","7",312,672,975,1475)
S("TruckDeluxe","7",636,995,15,530)
S("TruckRocket","7",640,995,505,1040)
S("TruckUfo","7",640,995,1040,1520)
# --- sheet 8: toppings
S("ToppingSprinkles","8",60,525,25,545)
S("ToppingChocolateSyrup","8",5,545,590,1030)
S("ToppingCherry","8",30,525,1085,1475)
S("ToppingWhippedCream","8",515,995,25,500)
S("ToppingCrushedCookies","8",535,995,515,1015)
S("ToppingGoldFlakes","8",525,1000,1030,1515)
for k,v in sizes.items(): print(f"{k:24s} {v[0]}x{v[1]}")
