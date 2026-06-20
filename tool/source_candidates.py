#!/usr/bin/env python3
"""Fetch several candidates for the categories that failed first-pass review,
so we can eyeball them and pick. Saves to assets/images/_cand/<name>_<i>.jpg and
prints an index with attribution."""
import json, os, re, sys, time, urllib.parse, urllib.request

UA = "VybiaImageSourcing/1.0 (https://vybia.app; samdimmai@gmail.com)"
API = "https://commons.wikimedia.org/w/api.php"
CAND = "assets/images/_cand"

TARGETS = {
    "social": ["group of friends toasting drinks restaurant",
               "friends laughing together cafe table"],
    "energetic": ["music festival crowd hands raised",
                  "people dancing nightclub lights"],
    "theatre": ["theatre auditorium interior empty seats stage",
                "concert hall interior seats balcony"],
    "gallery": ["modern art gallery interior visitors paintings",
                "art gallery white wall paintings people"],
}
BAD = ("map","diagram","logo","icon","chart","coat of arms","seal of","flag of","svg","sheet music","poster")

def api_get(params):
    url = API + "?" + urllib.parse.urlencode(dict(params, format="json"))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

def strip(s):
    return re.sub(r"\s+"," ", re.sub(r"<[^>]+>","", s or "")).strip()

def main():
    os.makedirs(CAND, exist_ok=True)
    index = {}
    for name, terms in TARGETS.items():
        got = 0
        for term in terms:
            data = api_get({"action":"query","generator":"search",
                "gsrsearch":f"filetype:bitmap {term}","gsrnamespace":"6",
                "gsrlimit":"12","prop":"imageinfo",
                "iiprop":"url|mime|size|extmetadata","iiurlwidth":"1280"})
            pages = sorted(data.get("query",{}).get("pages",{}).values(),
                           key=lambda p:p.get("index",999))
            for p in pages:
                if got >= 5: break
                ii=(p.get("imageinfo") or [{}])[0]
                title=p.get("title","").lower()
                if ii.get("mime")!="image/jpeg": continue
                if any(b in title for b in BAD): continue
                w,h=ii.get("width",0),ii.get("height",0)
                if w<1000 or h<700: continue
                if w and h and w/h>2.2: continue
                dest=os.path.join(CAND,f"{name}_{got}.jpg")
                try:
                    req=urllib.request.Request(ii["thumburl"],headers={"User-Agent":UA})
                    with urllib.request.urlopen(req,timeout=60) as r: d=r.read()
                    open(dest,"wb").write(d)
                except Exception as e:
                    print("dl err",e); continue
                em=ii.get("extmetadata",{})
                index[f"{name}_{got}"]={"title":p.get("title"),
                    "author":strip(em.get("Artist",{}).get("value")),
                    "license":strip(em.get("LicenseShortName",{}).get("value")),
                    "license_url":em.get("LicenseUrl",{}).get("value",""),
                    "descurl":ii.get("descriptionurl"),
                    "source_url":ii["thumburl"]}
                print(f"{name}_{got}: {p.get('title')} ({index[f'{name}_{got}']['license']})",flush=True)
                got+=1
            if got>=5: break
    json.dump(index, open("tool/_cand_sources.json","w"), indent=2, ensure_ascii=False)

if __name__=="__main__":
    main()
