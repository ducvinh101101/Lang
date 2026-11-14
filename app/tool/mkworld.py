import json,sys,math
src,dst=sys.argv[1],sys.argv[2]
d=json.load(open(src))
def dp(pts,tol):
    if len(pts)<3: return pts
    a,b=pts[0],pts[-1]
    dx,dy=b[0]-a[0],b[1]-a[1]; L=math.hypot(dx,dy)
    imax,dmax=0,0
    for i in range(1,len(pts)-1):
        p=pts[i]
        dd=abs(dy*p[0]-dx*p[1]+b[0]*a[1]-b[1]*a[0])/L if L>0 else math.hypot(p[0]-a[0],p[1]-a[1])
        if dd>dmax: imax,dmax=i,dd
    if dmax>tol:
        return dp(pts[:imax+1],tol)[:-1]+dp(pts[imax:],tol)
    return [a,b]
VI_FIX={'GBR':'Vương quốc Anh','PRK':'Triều Tiên','IRL':'Ai-len','CZE':'Séc','ZAF':'Nam Phi','TUN':'Tunisia','MMR':'Myanmar','ARE':'Các Tiểu vương quốc Ả Rập','KOR':'Hàn Quốc','USA':'Hoa Kỳ','SAU':'Ả Rập Xê Út','PHL':'Phi-líp-pin','COD':'Cộng hòa Dân chủ Congo','CYP':'Síp'}
out=[]
for f in d['features']:
    p=f['properties']; g=f['geometry']
    polys=g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
    rings=[]
    for poly in polys:
        r=poly[0]
        xs=[c[0] for c in r]; ys=[c[1] for c in r]
        ext=max(max(xs)-min(xs),max(ys)-min(ys))
        tol=0.03 if p['ADM0_A3'] in ('VNM','CHN','LAO','KHM','THA') else 0.06
        s=dp(r,tol)
        if len(s)<4: continue
        rings.append([v for c in s for v in (round(c[0]*100),round(c[1]*100))])
    if not rings: continue
    vi=VI_FIX.get(p['ADM0_A3']) or p.get('NAME_VI') or p['NAME']
    out.append({'a':p['ADM0_A3'],'vi':vi,'en':p['NAME'],'x':round(p['LABEL_X'],2),'y':round(p['LABEL_Y'],2),'r':rings,'k':p['LABELRANK']})
json.dump(out,open(dst,'w'),ensure_ascii=False,separators=(',',':'))
print(len(out))
