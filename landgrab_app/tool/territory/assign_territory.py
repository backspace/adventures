#!/usr/bin/env python3
"""Precompute one dissolved, contiguous territory polygon per pole.

Second half of the street-aware-territory pipeline. `generate_blocks.py` turns
OSM into a complete tiling of blocks; this assigns every block to a pole and
dissolves each pole's blocks into a single shape, so the app has ONE
authoritative polygon per pole — used for both drawing (no internal lines, no
gaps) and tapping (owner always matches the colour). Contiguity is guaranteed
by construction: assignment is a multi-source shortest-path (Dijkstra) over the
block-adjacency graph, so each pole's region is a connected BFS tree.

Design + rationale:
    ~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md

This is the local/offline stand-in for the eventual server-side step: the same
computation, run against a DB dump instead of live data. It intentionally reads
only geometry files (no DB), so the logic ports straight to the server.

Dependencies: pip install shapely

Usage:
    python3 assign_territory.py \\
        --blocks   ../../assets/experimental/blocks.geojson \\
        --poles    ../../assets/experimental/poles.geojson \\
        --puzzlets ../../assets/experimental/puzzlet_points.geojson \\
        --out      ../../assets/experimental/territory.geojson

`--poles`/`--puzzlets` are GeoJSON point features carrying `id` / `pole_id`.
"""
import argparse
import heapq
import json
import math
import sys


def load_blocks(path):
    from shapely.geometry import shape
    out = []
    for f in json.load(open(path)).get("features", []):
        g = shape(f["geometry"])
        for poly in (g.geoms if g.geom_type == "MultiPolygon" else [g]):
            if poly.is_valid and not poly.is_empty:
                out.append(poly)
    return out


def load_points(path, id_key):
    from shapely.geometry import shape
    pts = []
    if not path:
        return pts
    for f in json.load(open(path)).get("features", []):
        pid = (f.get("properties") or {}).get(id_key)
        if pid is None or f["geometry"]["type"] != "Point":
            continue
        pts.append((str(pid), shape(f["geometry"])))
    return pts


def adjacency(blocks):
    """Block index → set of edge-sharing neighbours."""
    from shapely import STRtree
    tree = STRtree(blocks)
    adj = [set() for _ in blocks]
    for i, b in enumerate(blocks):
        for j in tree.query(b):
            j = int(j)
            if j <= i:
                continue
            inter = b.intersection(blocks[j])
            # A shared edge has length; a corner-touch is a point (length 0).
            if not inter.is_empty and inter.length > 0:
                adj[i].add(j)
                adj[j].add(i)
    return adj


def _metres(a, b):
    # a, b are shapely Points (lng, lat). Local equirectangular metres.
    latm = 111000.0
    lonm = 111000.0 * math.cos(a.y * math.pi / 180)
    return math.hypot((a.x - b.x) * lonm, (a.y - b.y) * latm)


def build_units(blocks, poles, hull):
    """Turn blocks into assignment *units*, splitting any block that holds more
    than one pole by a Voronoi of those poles — so every pole gets its own
    slice of a shared/superblock instead of one pole taking the whole thing
    (which left the others with no zone). Returns (unit_geoms, unit_home) where
    unit_home[i] is the pole id that owns unit i outright, or None (an empty
    unit to be filled)."""
    from collections import defaultdict
    from shapely.geometry import MultiPoint
    from shapely.ops import voronoi_diagram

    in_hull = [i for i, b in enumerate(blocks)
               if hull.contains(b.representative_point())]
    cents = {i: blocks[i].representative_point() for i in in_hull}

    # Each pole → the block it stands in, else its nearest in-hull block.
    poles_in = defaultdict(list)
    for pid, pt in poles:
        home = next((i for i in in_hull if blocks[i].contains(pt)), None)
        if home is None and in_hull:
            home = min(in_hull, key=lambda i: _metres(cents[i], pt))
        if home is not None:
            poles_in[home].append((pid, pt))

    geoms, home = [], []
    for i in in_hull:
        here = poles_in.get(i, [])
        if len(here) <= 1:
            geoms.append(blocks[i])
            home.append(here[0][0] if here else None)
            continue
        # Split this block among its poles by their Voronoi.
        cells = voronoi_diagram(MultiPoint([pt for _, pt in here]),
                                envelope=blocks[i])
        for cell in cells.geoms:
            piece = cell.intersection(blocks[i])
            if piece.is_empty:
                continue
            owner_pid = next((pid for pid, pt in here if cell.contains(pt)), None)
            for poly in (piece.geoms if piece.geom_type == "MultiPolygon"
                         else [piece]):
                if poly.geom_type == "Polygon" and not poly.is_empty:
                    geoms.append(poly)
                    home.append(owner_pid)
    return geoms, home


def assign(units, unit_home, poles):
    """Multi-source Dijkstra on the unit-adjacency graph: each empty unit goes
    to the pole nearest by graph distance (straight-line tiebreak). Units that
    already have a home pole keep it. Returns unit index → pole id."""
    pt_of = {pid: pt for pid, pt in poles}
    adj = adjacency(units)
    cents = [u.representative_point() for u in units]

    owner = {}
    pq = []  # (graph_dist, straight_line, seq, unit, pole_id)
    seq = 0
    for i, pid in enumerate(unit_home):
        if pid is not None:
            sl = _metres(cents[i], pt_of[pid]) if pid in pt_of else 0.0
            heapq.heappush(pq, (0, sl, seq, i, pid))
            seq += 1

    while pq:
        gd, _sl, _, u, pid = heapq.heappop(pq)
        if u in owner:
            continue
        owner[u] = pid
        base = pt_of.get(pid)
        for n in adj[u]:
            if n not in owner:
                nsl = _metres(cents[n], base) if base is not None else 0.0
                heapq.heappush(pq, (gd + 1, nsl, seq, n, pid))
                seq += 1
    return owner


def dissolve(units, owner):
    """Union each pole's units; keep the largest connected piece so the result
    is a single contiguous polygon per pole."""
    from shapely.ops import unary_union
    from shapely.geometry import MultiPolygon

    by_pole = {}
    for u, pid in owner.items():
        by_pole.setdefault(pid, []).append(units[u])

    feats = []
    for pid, polys in by_pole.items():
        merged = unary_union(polys)
        if isinstance(merged, MultiPolygon):
            merged = max(merged.geoms, key=lambda p: p.area)
        ring = [[x, y] for x, y in merged.exterior.coords]
        feats.append({
            "type": "Feature",
            "properties": {"pole_id": pid},
            "geometry": {"type": "Polygon", "coordinates": [ring]},
        })
    return {"type": "FeatureCollection", "features": feats}


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--blocks", required=True)
    ap.add_argument("--poles", required=True)
    ap.add_argument("--puzzlets", default=None,
                    help="Included in the play-area hull so zones can reach "
                         "puzzlet locations")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    from shapely.geometry import MultiPoint

    blocks = load_blocks(args.blocks)
    poles = load_points(args.poles, "id")
    puzzlets = load_points(args.puzzlets, "pole_id")
    print(f"{len(blocks)} blocks, {len(poles)} poles, {len(puzzlets)} puzzlets",
          file=sys.stderr)

    seeds = [pt for _, pt in poles] + [pt for _, pt in puzzlets]
    hull = MultiPoint(seeds).convex_hull

    units, unit_home = build_units(blocks, poles, hull)
    seeded = sum(1 for h in unit_home if h is not None)
    print(f"{len(units)} units ({seeded} pole-seeded)", file=sys.stderr)

    owner = assign(units, unit_home, poles)
    print(f"{len(owner)} units assigned to {len(set(owner.values()))} poles",
          file=sys.stderr)

    fc = dissolve(units, owner)
    json.dump(fc, open(args.out, "w"))
    print(f"Wrote {args.out} — {len(fc['features'])} territories",
          file=sys.stderr)


if __name__ == "__main__":
    main()
