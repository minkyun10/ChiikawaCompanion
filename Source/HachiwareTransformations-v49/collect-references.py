#!/usr/bin/env python3
"""Collect public official references; never alter runtime artwork."""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urlsplit
from concurrent.futures import ThreadPoolExecutor
import hashlib, json

ROOT=Path(__file__).resolve().parent
records=[]
def fetch(url):
    with urlopen(Request(url,headers={"User-Agent":"Mozilla/5.0"}),timeout=30) as response:
        data=response.read()
        return data,response.headers.get("Content-Type",""),response.geturl()
def save(url,relative,category,kind="reference-image",page=None):
    path=ROOT/relative
    data,content_type,resolved=fetch(url)
    if kind=="reference-image" and not content_type.startswith("image/"):
        raise ValueError("Expected image: "+url)
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    record={"path":str(path.relative_to(ROOT)),"url":url,"page":page or url,
            "category":category,"kind":kind,"verified":"2026-10-23","content_type":content_type,
            "bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}
    if resolved!=url:record["resolved_url"]=resolved
    records.append(record)
    return data
def snapshot(url,name,category):
    return json.loads(save(url,"Metadata/"+name,category,"official-source-document"))

episodes=snapshot("https://a2.fujitv.co.jp/ca2/sloth/v1/polling?o=119","episodes-current.json","episode-index")
history=snapshot("https://www.anime-chiikawa.jp/json/episodeHistories.json","episodes-history.json","episode-index")
wanted=set(["036","037","038","039"]+[str(n) for n in range(172,178)]+[str(n) for n in range(375,383)])
indexed={e["no"]:e for e in history["episodes"]+episodes["episodes"] if e["no"] in wanted}
(ROOT/"episode-index.json").write_text(json.dumps([indexed[n] for n in sorted(indexed)],ensure_ascii=False,indent=2)+"\n")
jobs=[]
for no,episode in indexed.items():
    category="wand-giant" if int(no)<100 else "fairy-dream" if int(no)<200 else "parallel-world"
    url="https://www.anime-chiikawa.jp/images/episodes/"+episode["img"]
    jobs.append((url,"References/Official/Anime/episode-"+no+".jpg",category,"reference-image","https://www.anime-chiikawa.jp/episode.html"))

products=[
 ("4571609344094","parallel-mid",7),
 ("4571609344117","parallel-strong",6),
 ("4571609347347","parallel-strong",3),
 ("4570189191586","parallel-strong",2),
 ("4571609413776","magical-strong-product",4),
 ("4979274946726","fairy-dream",2),
 ("4573256438690","magical-costume",2),
 ("4571609366843","magical-costume-bad-version",1)
]
product_index=[]
for code,category,limit in products:
    page="https://chiikawamarket.jp/products/"+code
    product=snapshot(page+".js","product-"+code+".json",category)
    image_urls=[image if isinstance(image,str) else image["src"] for image in product.get("images",[])]
    if code=="4571609413776":
        image_urls=[url for url in image_urls if code in url]
    chosen=image_urls[:limit]
    product_index.append({"id":code,"title":product["title"],"page":page,"category":category,
                          "available_image_count":len(product.get("images",[])),"collected_image_count":len(chosen)})
    for i,image in enumerate(chosen,1):
        url="https:"+image if image.startswith("//") else image
        suffix=Path(urlsplit(url).path).suffix.lower()
        jobs.append((url,f"References/Official/Market/{category}-{code}-{i:02d}"+suffix,category,"reference-image",page))
(ROOT/"product-index.json").write_text(json.dumps(product_index,ensure_ascii=False,indent=2)+"\n")

tweets=[
 ("2102236239995031704","parallel-stages"),
 ("1765317655823839639","parallel-strong"),
 ("1767525203222143077","parallel-strong"),
 ("1302210937236013059","wand-giant"),
 ("1302963721396867072","wand-giant")
]
tweet_index=[]
for post,category in tweets:
    url="https://cdn.syndication.twimg.com/tweet-result?id="+post+"&lang=ja&token=0"
    tweet=snapshot(url,"official-post-"+post+".json",category)
    if tweet.get("user",{}).get("screen_name")!="ngnchiikawa":
        raise ValueError("Official author verification failed: "+post)
    page="https://x.com/ngnchiikawa/status/"+post
    tweet_index.append({"id":post,"page":page,"category":category,"author":"ngnchiikawa",
                        "created_at":tweet.get("created_at"),"text":tweet.get("text"),"images":len(tweet.get("photos",[])),
                        "verification_method":"public X syndication response identifies official author and image URL"})
    for i,photo in enumerate(tweet.get("photos",[]),1):
        url=photo["url"]
        suffix=Path(urlsplit(url).path).suffix.lower()
        jobs.append((url,f"References/Official/OriginalComic/{category}-{post}-{i:02d}"+suffix,category,"reference-image",page))
(ROOT/"official-post-index.json").write_text(json.dumps(tweet_index,ensure_ascii=False,indent=2)+"\n")

failures=[]
def collect(job):
    try:save(*job);return None
    except Exception as error:return {"url":job[0],"path":job[1],"error":str(error)}
with ThreadPoolExecutor(max_workers=4) as pool:
    for failure in pool.map(collect,jobs):
        if failure:failures.append(failure)
(ROOT/"sources.json").write_text(json.dumps(sorted(records,key=lambda r:r["path"]),ensure_ascii=False,indent=2)+"\n")
(ROOT/"collection-status.json").write_text(json.dumps({"verified":"2026-10-23","files":len(records),
    "images":sum(r["kind"]=="reference-image" for r in records),"failures":failures,
    "scope":"Official anime, official creator X public posts, official Chiikawa Market only; no generated art or runtime edits."},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"images":sum(r["kind"]=="reference-image" for r in records),"files":len(records),"failures":failures},ensure_ascii=False))
