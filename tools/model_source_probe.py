#!/usr/bin/env python3
import json
import urllib.request

IDS = [
    "Chandelier_02", "Chandelier_01", "brass_candleholders",
    "marble_bust_01", "fancy_picture_frame_01",
    "security_camera_01", "wine_bottles_01",
    "bar_chair_round_01", "CoffeeCart_01", "modern_wooden_cabinet",
]
for identifier in IDS:
    try:
        request = urllib.request.Request(
            "https://api.polyhaven.com/files/" + identifier,
            headers={"User-Agent": "CasinoAnomalyDevelopmentAssetAudit/1.0"}
        )
        with urllib.request.urlopen(request, timeout=25) as response:
            files = json.load(response)
        gltf = files.get("gltf", {})
        summary = {}
        for resolution in ["1k", "2k", "4k"]:
            selected = gltf.get(resolution, {})
            if not selected:
                continue
            variant = selected.get("gltf") or next(iter(selected.values()))
            includes = variant.get("include", {})
            summary[resolution] = {
                "size": variant.get("size"),
                "url": variant.get("url"),
                "include_count": len(includes),
                "include_MB": round(sum(x.get("size", 0) for x in includes.values()) / 1e6, 2),
                "include_sample": [{"path": k, "url": v.get("url"), "size": v.get("size")}
                                   for k, v in list(includes.items())[:3]],
                "formats": list(selected),
            }
        print(json.dumps({"id": identifier, "resolutions": summary, "top_level": list(files)},
                         ensure_ascii=False), flush=True)
    except Exception as exc:
        print(json.dumps({"id": identifier, "error": str(exc)}), flush=True)
