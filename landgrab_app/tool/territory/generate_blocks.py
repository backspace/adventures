#!/usr/bin/env python3
"""Generate city-block polygons for the street-aware-territory experiment.

Fetches the road network for a bounding box from OpenStreetMap (Overpass),
polygonizes it into the faces enclosed by streets ("blocks"), and writes a
GeoJSON FeatureCollection the app loads at assets/experimental/blocks.geojson.

This runs OFFLINE, on your machine — the app never fetches OSM at runtime; it
ships these precomputed shapes. Re-run whenever the venue (bbox) changes.

Design + rationale:
    ~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md

Dependencies:
    pip install requests shapely

Usage:
    python3 generate_blocks.py \\
        --bbox <south> <west> <north> <east> \\
        --out ../../assets/experimental/blocks.geojson

Tips:
  * Keep the bbox tight to the play area — smaller is faster and cleaner.
  * --highways controls which ways count as "streets". The default drops
    footways/paths/service so blocks follow real roads; widen it if the venue's
    paths matter.
"""
import argparse
import hashlib
import json
import os
import sys

DEFAULT_HIGHWAYS = [
    "primary", "secondary", "tertiary", "residential",
    "unclassified", "living_street", "trunk",
]

# Public Overpass mirrors, tried in order. The main endpoint sits behind a WAF
# that 406s the default python-requests User-Agent, so we send a real one and
# fall through to a mirror on any failure.
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

HEADERS = {
    "User-Agent": "landgrab-territory-generator/1.0 (offline block precompute)",
    "Accept": "application/json",
}


def cached(cache_dir, name, key, refresh, producer):
    """Return locally-cached fetch output for [key], or call [producer] (a live
    Overpass fetch) and cache it. Lets you iterate on block params without
    re-hitting OSM every run. `--refresh` forces a re-fetch."""
    if not cache_dir:
        return producer()
    os.makedirs(cache_dir, exist_ok=True)
    h = hashlib.sha1(key.encode()).hexdigest()[:16]
    path = os.path.join(cache_dir, f"{name}-{h}.json")
    if not refresh and os.path.exists(path):
        print(f"  cache hit: {path}", file=sys.stderr)
        with open(path) as f:
            return json.load(f)
    data = producer()
    with open(path, "w") as f:
        json.dump(data, f)
    print(f"  cached: {path}", file=sys.stderr)
    return data


def fetch_roads(south, west, north, east, highways, endpoints=None, alleys=True):
    import requests

    bbox = f"{south},{west},{north},{east}"
    regex = "|".join(highways)
    parts = [f'way["highway"~"^({regex})$"]({bbox});']
    if alleys:
        # Real alleys only. `service=alley` splits a block down its mid-block
        # lane (useful); footway/path are mostly *sidewalks* that shave thin
        # strips off every block (the "comical slices"), and pedestrian ways
        # are often plaza edges — all excluded on purpose. Widen via --highways
        # if a venue genuinely needs them.
        parts.append(f'way["highway"="service"]["service"="alley"]({bbox});')
    query = "[out:json][timeout:60];(" + "".join(parts) + ");out geom;"

    last_err = None
    for url in endpoints or ENDPOINTS:
        try:
            resp = requests.post(
                url, data={"data": query}, headers=HEADERS, timeout=90
            )
            resp.raise_for_status()
            data = resp.json()
            break
        except Exception as e:  # noqa: BLE001 — try the next mirror
            print(f"  {url} failed: {e}", file=sys.stderr)
            last_err = e
    else:
        raise SystemExit(
            f"All Overpass endpoints failed. Last error: {last_err}\n"
            "Check connectivity, or pass --endpoint <url>."
        )

    lines = []
    for el in data.get("elements", []):
        geom = el.get("geometry")
        if not geom or len(geom) < 2:
            continue
        lines.append([(pt["lon"], pt["lat"]) for pt in geom])
    return lines


def _fetch_area_rings(query, endpoints, label):
    """POST an Overpass area query and return every way/relation-member ring
    (coordinate lists). Ways carry `geometry`; relations carry members'
    geometry — take them all and let polygonize assemble the areas."""
    import requests

    last_err = None
    for url in endpoints or ENDPOINTS:
        try:
            resp = requests.post(
                url, data={"data": query}, headers=HEADERS, timeout=90)
            resp.raise_for_status()
            data = resp.json()
            break
        except Exception as e:  # noqa: BLE001
            print(f"  {label} fetch via {url} failed: {e}", file=sys.stderr)
            last_err = e
    else:
        print(f"  no {label} fetched ({last_err}) — continuing without it",
              file=sys.stderr)
        return []

    lines = []
    for el in data.get("elements", []):
        g = el.get("geometry")
        if g and len(g) >= 2:
            lines.append([(pt["lon"], pt["lat"]) for pt in g])
        for m in el.get("members", []):
            mg = m.get("geometry")
            if mg and len(mg) >= 2:
                lines.append([(pt["lon"], pt["lat"]) for pt in mg])
    return lines


def fetch_water(south, west, north, east, endpoints=None):
    """Water-body rings (rivers, riverbanks, lakes). Used both to *close*
    blocks a street doesn't bound (the river is the fourth edge) and to *clip*
    blocks back to the bank."""
    bbox = f"{south},{west},{north},{east}"
    query = (
        "[out:json][timeout:60];("
        f'way["natural"="water"]({bbox});'
        f'way["waterway"="riverbank"]({bbox});'
        f'way["water"]({bbox});'
        f'relation["natural"="water"]({bbox});'
        ");out geom;"
    )
    return _fetch_area_rings(query, endpoints, "water")


def fetch_areas(south, west, north, east, endpoints=None):
    """Open-space "property" rings — parks, gardens, greens, recreation land.
    These become blocks in their own right, so land the street grid doesn't
    enclose (riverfront parks, plazas) still belongs to a zone instead of
    reading as a blank gap."""
    bbox = f"{south},{west},{north},{east}"
    leisure = "park|garden|recreation_ground|common|pitch|playground|nature_reserve"
    landuse = "grass|recreation_ground|meadow|forest|village_green|greenfield"
    query = (
        "[out:json][timeout:60];("
        f'way["leisure"~"^({leisure})$"]({bbox});'
        f'way["landuse"~"^({landuse})$"]({bbox});'
        f'relation["leisure"~"^({leisure})$"]({bbox});'
        f'relation["landuse"~"^({landuse})$"]({bbox});'
        ");out geom;"
    )
    return _fetch_area_rings(query, endpoints, "areas")


def build_blocks(bbox, road_lines, water_lines, area_lines, min_area_m2,
                 merge_below_m2):
    from shapely.geometry import LineString, MultiPolygon, Polygon, box
    from shapely.ops import polygonize, unary_union

    south, west, north, east = bbox

    def as_lines(rings):
        return [LineString(c) for c in rings if len(c) >= 2]

    def explode(g):
        if g.is_empty:
            return []
        parts = g.geoms if isinstance(g, MultiPolygon) else [g]
        return [p for p in parts if isinstance(p, Polygon) and not p.is_empty]

    def area_of(lines):
        if not lines:
            return None
        polys = list(polygonize(unary_union(lines)))
        return unary_union(polys) if polys else None

    # Complete tiling: every boundary line — streets, alleys, the river's edge,
    # park edges — plus the bbox rectangle so nothing stays open, polygonized
    # into faces that tile the whole box with NO gaps between them. (The old
    # approach overlaid street faces and park polygons, which left voids
    # wherever a park edge didn't meet a road centreline — e.g. around a
    # roundabout.)
    frame = LineString(box(west, south, east, north).exterior.coords)
    all_lines = (as_lines(road_lines) + as_lines(water_lines) +
                 as_lines(area_lines) + [frame])
    faces = list(polygonize(unary_union(all_lines)))

    water = area_of(as_lines(water_lines))
    parks = area_of(as_lines(area_lines))

    # Keep every face except open water. A face is dropped only if it's in the
    # river AND not in a park — parks are dry land and win over a river polygon
    # that OSM drew onto the shore.
    kept = []
    for f in faces:
        c = f.representative_point()
        in_water = water is not None and water.contains(c)
        in_park = parks is not None and parks.contains(c)
        if in_water and not in_park:
            continue
        kept.extend(explode(f))

    polys = _merge_slivers(kept, merge_below_m2)
    return [p for p in polys if _area_m2(p) >= min_area_m2]


def _merge_slivers(polys, merge_below_m2):
    """Fold faces smaller than [merge_below_m2] into the neighbour they share
    the most boundary with. Absorbs the thin triangles roundabouts and
    Y-junctions leave behind (e.g. the Waterfront Drive circle) instead of
    letting them read as their own micro-zone."""
    from shapely.ops import unary_union

    polys = list(polys)
    while True:
        order = sorted(range(len(polys)), key=lambda i: _area_m2(polys[i]))
        merged_one = False
        for i in order:
            if _area_m2(polys[i]) >= merge_below_m2:
                break  # everything left is big enough
            s = polys[i]
            best_j, best_len = None, 0.0
            for j, q in enumerate(polys):
                if j == i:
                    continue
                shared = s.boundary.intersection(q.boundary).length
                if shared > best_len:
                    best_len, best_j = shared, j
            if best_j is not None and best_len > 0:
                polys[best_j] = unary_union([polys[best_j], s])
                del polys[i]
                merged_one = True
                break  # indices shifted — restart the scan
        if not merged_one:
            break

    # A union can occasionally yield a MultiPolygon (faces touching at a
    # point); split those back out.
    from shapely.geometry import MultiPolygon
    out = []
    for p in polys:
        if isinstance(p, MultiPolygon):
            out.extend(p.geoms)
        else:
            out.append(p)
    return out


def _area_m2(poly):
    # Local equirectangular metres — good enough to drop slivers.
    import math
    c = poly.centroid
    per_lat = 111000.0
    per_lon = 111000.0 * math.cos(c.y * math.pi / 180)
    return poly.area * per_lat * per_lon


def _poly_coords(poly):
    # GeoJSON Polygon: [exterior, hole1, …]. Interior rings MUST be kept — a
    # block can wrap an inner block (courtyard); dropping the hole fills it in
    # and the block then overlaps whatever sat inside.
    rings = [[[x, y] for (x, y) in poly.exterior.coords]]
    rings += [[[x, y] for (x, y) in r.coords] for r in poly.interiors]
    return rings


def to_geojson(blocks):
    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {"id": f"b{i}"},
                "geometry": {"type": "Polygon", "coordinates": _poly_coords(poly)},
            }
            for i, poly in enumerate(blocks)
        ],
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bbox", nargs=4, type=float, required=True,
                    metavar=("SOUTH", "WEST", "NORTH", "EAST"))
    ap.add_argument("--out", required=True, help="Output GeoJSON path")
    ap.add_argument("--highways", nargs="+", default=DEFAULT_HIGHWAYS,
                    help="OSM highway values to treat as streets")
    ap.add_argument("--endpoint", action="append", default=None,
                    help="Overpass endpoint URL (repeatable); overrides the "
                         "built-in mirror list")
    ap.add_argument("--no-river", action="store_true",
                    help="Skip water fetch; blocks follow streets only")
    ap.add_argument("--no-parks", action="store_true",
                    help="Skip parks/landuse; land the streets don't enclose "
                         "(riverfront, plazas) stays a blank gap")
    ap.add_argument("--alleys", action=argparse.BooleanOptionalAction,
                    default=True,
                    help="Include alleys + pedestrian ways so blocks subdivide "
                         "finer (default: on)")
    ap.add_argument("--min-area-m2", type=float, default=60.0,
                    help="Drop unmergeable slivers smaller than this (m²)")
    ap.add_argument("--merge-below-m2", type=float, default=500.0,
                    help="Fold faces smaller than this into their largest "
                         "neighbour (roundabout islands / junction slivers). "
                         "Raise it (e.g. 1000) if a traffic circle persists.")
    ap.add_argument("--cache-dir", default=os.path.join(
                        os.path.dirname(__file__), ".cache"),
                    help="Where to cache raw OSM fetches (default: "
                         "tool/territory/.cache); '' disables caching")
    ap.add_argument("--refresh", action="store_true",
                    help="Ignore the cache and re-fetch from OSM")
    args = ap.parse_args()

    south, west, north, east = args.bbox
    bbox = f"{south},{west},{north},{east}"

    print(f"Fetching roads for bbox {bbox} …", file=sys.stderr)
    roads_key = f"roads|{bbox}|{'|'.join(args.highways)}|alleys={args.alleys}"
    road_lines = cached(
        args.cache_dir, "roads", roads_key, args.refresh,
        lambda: fetch_roads(south, west, north, east, args.highways,
                            args.endpoint, alleys=args.alleys))
    print(f"  {len(road_lines)} road/alley ways", file=sys.stderr)

    water_lines = []
    if not args.no_river:
        print("Fetching water …", file=sys.stderr)
        water_lines = cached(
            args.cache_dir, "water", f"water|{bbox}", args.refresh,
            lambda: fetch_water(south, west, north, east, args.endpoint))
        print(f"  {len(water_lines)} water ways", file=sys.stderr)

    area_lines = []
    if not args.no_parks:
        print("Fetching parks/landuse …", file=sys.stderr)
        area_lines = cached(
            args.cache_dir, "areas", f"areas|{bbox}", args.refresh,
            lambda: fetch_areas(south, west, north, east, args.endpoint))
        print(f"  {len(area_lines)} property ways", file=sys.stderr)

    blocks = build_blocks((south, west, north, east), road_lines, water_lines,
                          area_lines, args.min_area_m2, args.merge_below_m2)
    print(f"  {len(blocks)} blocks", file=sys.stderr)

    with open(args.out, "w") as f:
        json.dump(to_geojson(blocks), f)
    print(f"Wrote {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
