#!/usr/bin/env python3
"""Collect selected, publicly accessible official references without modifying images."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from hashlib import sha256
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
class Images(HTMLParser):
    def __init__(self):
        super().__init__(); self.images=[]; self.links=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag=='img':
            src=a.get('data-src') or a.get('src')
            if src: self.images.append(src)
        if tag=='a' and a.get('href','').split('?')[0].lower().endswith(('.jpg','.png','.jpeg')):
            self.links.append(a['href'])

def fetch(url):
    with urlopen(Request(url,headers={'User-Agent':'Mozilla/5.0 (personal character reference collection)'}),timeout=30) as response:
        return response.read(), response.headers.get('Content-Type','')

def discover():
    selections=[{'page_url':'https://www.anime-chiikawa.jp/',
        'discovery_url':'https://www.anime-chiikawa.jp/css/style.css',
        'asset_url':'https://www.anime-chiikawa.jp/images/bg_top_chiikawa_01.png',
        'file':'chiikawa-anime-front.png','publisher':'Chiikawa anime official / Chiikawa production committee',
        'role':'Primary 2D anatomy and line-art reference'}]
    page='https://www.chiikawaofficial.com/characters/'
    p=Images(); p.feed(fetch(page)[0].decode('utf-8'))
    image=next(i for i in p.images if '1719x1338+pale+Pink+Bubble' in i)
    selections.append({'page_url':page,'asset_url':image,'file':'chiikawa-official-page-background.png','publisher':'Spiralcute / Chiikawa official','role':'Decorative page background; retained as collected material, excluded from character anatomy references.'})
    page='https://www.goodsmile.info/ja/product/14452'
    p=Images(); p.feed(fetch(page)[0].decode('utf-8'))
    links=list(dict.fromkeys(urljoin(page,s) for s in p.links if '/14452/' in s and '/large/' in s))
    assert len(links)>=4
    roles=['Front face and body proportions; open happy expression',
           'Closed-eye happy expression; pink bear-face pochette and narrow white crossbody strap',
           'Nervous crying face; horizontally held pink sasumata with white spikes',
           'Crying face and diagonally held sasumata pose',
           'Group scale and seated expressions; focus only on Chiikawa',
           'Group scale and standing happy expression; focus only on Chiikawa']
    for i,url in enumerate(links):
        selections.append({'page_url':page,'asset_url':url,'file':f'chiikawa-official-figure-{i+1:02}.jpg','publisher':'Good Smile Company / Max Factory','role':roles[i] if i<len(roles) else 'Supplementary official figure image'})
    return selections

def download(record):
    data,content_type=fetch(record['asset_url'])
    assert content_type.startswith('image/'),content_type
    path=ROOT/'References/Official'/record['file']
    if path.exists() and path.read_bytes()!=data:
        old=ROOT/'References/Official/Versions'/sha256(path.read_bytes()).hexdigest()[:16]/path.name
        old.parent.mkdir(parents=True,exist_ok=True);old.write_bytes(path.read_bytes())
    path.write_bytes(data)
    return {**record,'path':str(path.relative_to(ROOT)),'bytes':len(data),'sha256':sha256(data).hexdigest(),'content_type':content_type}

if __name__=='__main__':
    selected=discover()
    with ThreadPoolExecutor(max_workers=4) as pool:
        files=list(pool.map(download,selected))
    result={'verified':'2026-10-20','collected_at':datetime.now(timezone.utc).isoformat(),'purpose':'Personal fan-made desktop companion reference and future reuse; source material is distinct from generated production artwork.','sources':files,'limitations':['Official product photographs guide shapes and expressions; the sprite style follows the existing 2D companion.','Rear, top, T-pose and walking in-betweens are production interpretations unless a separate source is cited.','No Korean voice recording is claimed or synthesized.']}
    (ROOT/'references.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'Collected and hashed {len(files)} official reference images.')
