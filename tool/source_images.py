#!/usr/bin/env python3
"""Source category-accurate, free-licensed images from Wikimedia Commons.

For each (name, search term) it queries the Commons API, picks the first
high-quality JPEG bitmap, downloads it at ~1280px, and records full attribution
(title, author, license, source URL) so a NOTICES file can be generated.

Run: python3 tool/source_images.py
Output: assets/images/_staging/<name>.jpg  + tool/_image_sources.json
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = "VybiaImageSourcing/1.0 (https://vybia.app; samdimmai@gmail.com)"
API = "https://commons.wikimedia.org/w/api.php"
STAGING = "assets/images/_staging"
SOURCES = "tool/_image_sources.json"

# name -> ordered list of search terms (later terms are fallbacks)
TARGETS = {
    # --- place categories (real OSM categories the engine uses) ---
    "cafe": ["cozy coffee shop interior", "cafe interior counter espresso"],
    "restaurant": ["restaurant dining room interior elegant", "bistro interior tables"],
    "bar": ["cocktail bar counter evening", "bar interior bottles night"],
    "cinema": ["cinema auditorium screen seats", "movie theater empty seats"],
    "theatre": ["theatre auditorium stage red seats", "opera house auditorium interior"],
    "museum": ["museum gallery hall interior", "museum interior exhibition hall"],
    "gallery": ["art gallery paintings wall exhibition", "contemporary art gallery interior"],
    "viewpoint": ["Montreal skyline view", "city skyline overlook viewpoint"],
    "park": ["urban park green trees path autumn", "city park lawn trees"],
    "garden": ["botanical garden flowers path", "formal garden green flowers"],
    "market": ["public market hall food stalls", "indoor market hall produce"],
    "sports": ["indoor climbing gym wall", "fitness gym interior equipment"],
    # --- mood / emotion images (must be sensible, not literal animals) ---
    "calm": ["calm misty lake morning serene", "still water mist dawn"],
    "curious": ["winding path forest sunlight", "open road horizon journey"],
    "social": ["friends toasting drinks together", "people celebrating together cheers"],
    "energetic": ["people dancing concert lights energy", "city runner motion blur"],
}

BAD_WORDS = ("map", "plan ", "diagram", "logo", "icon", "chart", "panorama of",
             "coat of arms", "seal of", "flag of", "svg")


def api_get(params):
    params = dict(params, format="json")
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)


def strip_html(s):
    if not s:
        return ""
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"\s+", " ", s).strip()


def search_candidates(term):
    data = api_get({
        "action": "query",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {term}",
        "gsrnamespace": "6",
        "gsrlimit": "12",
        "prop": "imageinfo",
        "iiprop": "url|mime|size|extmetadata",
        "iiurlwidth": "1280",
    })
    pages = data.get("query", {}).get("pages", {})
    # search generator returns an 'index' ordering; sort by it
    out = sorted(pages.values(), key=lambda p: p.get("index", 999))
    return out


def pick(candidates):
    for p in candidates:
        ii = (p.get("imageinfo") or [{}])[0]
        title = p.get("title", "").lower()
        if ii.get("mime") != "image/jpeg":
            continue
        if any(b in title for b in BAD_WORDS):
            continue
        w, h = ii.get("width", 0), ii.get("height", 0)
        if w < 1000 or h < 700:
            continue
        # avoid extreme panoramas (bad for full-bleed portrait cover)
        if w and h and (w / h > 2.4):
            continue
        return p, ii
    return None, None


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def main():
    os.makedirs(STAGING, exist_ok=True)
    sources = {}
    for name, terms in TARGETS.items():
        chosen = None
        for term in terms:
            try:
                cands = search_candidates(term)
            except Exception as e:
                print(f"[{name}] search error '{term}': {e}", flush=True)
                time.sleep(1)
                continue
            page, ii = pick(cands)
            if page:
                chosen = (term, page, ii)
                break
        if not chosen:
            print(f"[{name}] NO CANDIDATE FOUND", flush=True)
            continue
        term, page, ii = chosen
        em = ii.get("extmetadata", {})
        dest = os.path.join(STAGING, f"{name}.jpg")
        try:
            n = download(ii["thumburl"], dest)
        except Exception as e:
            print(f"[{name}] download error: {e}", flush=True)
            continue
        sources[name] = {
            "title": page.get("title"),
            "term": term,
            "author": strip_html(em.get("Artist", {}).get("value")),
            "license": strip_html(em.get("LicenseShortName", {}).get("value")),
            "license_url": em.get("LicenseUrl", {}).get("value", ""),
            "credit": strip_html(em.get("Credit", {}).get("value"))[:200],
            "descurl": ii.get("descriptionurl"),
            "source_url": ii["thumburl"],
            "width": ii.get("width"),
            "height": ii.get("height"),
            "bytes": n,
        }
        print(f"[{name}] OK {n//1024}KB  {page.get('title')}  ({sources[name]['license']})", flush=True)
        time.sleep(0.5)

    with open(SOURCES, "w") as f:
        json.dump(sources, f, indent=2, ensure_ascii=False)
    print(f"\nWrote {len(sources)} sources -> {SOURCES}", flush=True)


if __name__ == "__main__":
    main()
