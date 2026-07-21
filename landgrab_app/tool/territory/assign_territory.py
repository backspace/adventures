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


def _split_block(block, plist):
    """Partition [block] among the poles in [plist] by their Voronoi bisectors,
    as half-plane clips in local metres. (shapely's voronoi_diagram produced
    overlapping cells when a pole sat just outside the block it was nearest to;
    independent half-plane clipping is robust to that and always disjoint.)
    Returns [(pole_id, polygon)]."""
    import math
    from shapely.affinity import affine_transform
    from shapely.geometry import Polygon

    c = block.representative_point()
    sx = 111000.0 * math.cos(c.y * math.pi / 180)
    sy = 111000.0
    bm = affine_transform(block, [sx, 0, 0, sy, -c.x * sx, -c.y * sy])
    pts = [(pid, ((pt.x - c.x) * sx, (pt.y - c.y) * sy)) for pid, pt in plist]

    out = []
    for pid, (px, py) in pts:
        cell = bm
        for qid, (qx, qy) in pts:
            if qid == pid:
                continue
            nx, ny = qx - px, qy - py
            nl = math.hypot(nx, ny)
            if nl < 0.01:
                # Coincident poles (bad data: stacked at one coordinate) have
                # no bisector, so both would otherwise take the whole block and
                # overlap. Give it to the lowest id deterministically; the rest
                # get nothing (they're on the same spot — no distinct zone).
                if str(qid) < str(pid):
                    cell = Polygon()  # this pole loses the shared spot
                    break
                continue
            mx, my = (px + qx) / 2, (py + qy) / 2
            big = 5000.0
            # a large rectangle on p's side of the perpendicular bisector
            ax, ay = -ny / nl * big, nx / nl * big   # along the bisector
            ox, oy = -nx / nl * big, -ny / nl * big  # toward p
            hp = Polygon([
                (mx + ax, my + ay), (mx - ax, my - ay),
                (mx - ax + ox, my - ay + oy), (mx + ax + ox, my + ay + oy),
            ])
            cell = cell.intersection(hp)
            if cell.is_empty:
                break
        if not cell.is_empty:
            out.append((pid, affine_transform(cell, [1 / sx, 0, 0, 1 / sy, c.x, c.y])))
    return out


def build_units(blocks, poles, hull):
    """Turn blocks into assignment *units*, splitting any block that holds more
    than one pole among those poles — so every pole gets its own slice of a
    shared/superblock instead of one pole taking the whole thing (which left
    the others with no zone). Returns (unit_geoms, unit_home) where
    unit_home[i] is the pole id that owns unit i outright, or None (an empty
    unit to be filled)."""
    from collections import defaultdict

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
        for pid, piece in _split_block(blocks[i], here):
            for poly in (piece.geoms if piece.geom_type == "MultiPolygon"
                         else [piece]):
                if poly.geom_type == "Polygon" and not poly.is_empty:
                    geoms.append(poly)
                    home.append(pid)
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


def _reach_cap(seed_pts, reach_m):
    """Union of `reach_m`-radius discs around a pole's own seeds (the pole +
    its puzzlets), as a lat/lng polygon. A territory is clipped to this so it
    can't sprawl far past where the team actually has content — the fill fills
    gaps *between* poles, it shouldn't run hundreds of metres down an empty
    riverbank."""
    import math
    from shapely.geometry import Polygon
    from shapely.ops import unary_union

    discs = []
    for p in seed_pts:
        dlat = reach_m / 111000.0
        dlng = reach_m / (111000.0 * math.cos(p.y * math.pi / 180))
        discs.append(Polygon([
            (p.x + dlng * math.cos(2 * math.pi * k / 48),
             p.y + dlat * math.sin(2 * math.pi * k / 48))
            for k in range(48)
        ]))
    return unary_union(discs)


def dissolve(units, owner, seeds_by_pole, reach_m):
    """Union each pole's units, clip to its reach cap, keep the largest
    connected piece, and fill holes that no other zone occupies — one
    contiguous, extent-limited polygon per pole."""
    from shapely.ops import unary_union
    from shapely.geometry import MultiPolygon, Polygon

    by_pole = {}
    for u, pid in owner.items():
        by_pole.setdefault(pid, []).append(units[u])

    # First pass: each pole's clipped, single-piece region (holes intact).
    regions = {}
    for pid, polys in by_pole.items():
        merged = unary_union(polys)
        seeds = seeds_by_pole.get(pid)
        if reach_m and seeds:
            merged = merged.intersection(_reach_cap(seeds, reach_m))
        if merged.is_empty:
            continue
        if isinstance(merged, MultiPolygon):
            merged = max(merged.geoms, key=lambda p: p.area)
        if merged.geom_type == "Polygon" and not merged.is_empty:
            regions[pid] = merged

    all_union = unary_union(list(regions.values())) if regions else None

    feats = []
    for pid, merged in regions.items():
        # Keep only holes that a *different* zone actually fills; drop (fill)
        # empty pockets — the thin alley/service slivers that read as stray
        # lines. Filling an unowned hole can't overlap anyone (nobody's there).
        keep = []
        for r in merged.interiors:
            hole = Polygon(r)
            others = all_union.difference(merged) if all_union else None
            if others is not None and hole.intersection(others).area > 0.3 * hole.area:
                keep.append([[x, y] for x, y in r.coords])
        rings = [[[x, y] for x, y in merged.exterior.coords]] + keep
        feats.append({
            "type": "Feature",
            "properties": {"pole_id": pid},
            "geometry": {"type": "Polygon", "coordinates": rings},
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
    ap.add_argument("--max-reach-m", type=float, default=150.0,
                    help="Cap how far a zone extends past the team's own poles "
                         "and puzzlets (metres). 0 disables the cap.")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    from shapely.geometry import MultiPoint

    blocks = load_blocks(args.blocks)
    poles = load_points(args.poles, "id")
    puzzlets = load_points(args.puzzlets, "pole_id")
    print(f"{len(blocks)} blocks, {len(poles)} poles, {len(puzzlets)} puzzlets",
          file=sys.stderr)

    # Each pole's own seeds (itself + its puzzlets) — the reach cap radiates
    # from these, so a zone stays near where its team actually has content.
    seeds_by_pole = {}
    for pid, pt in poles:
        seeds_by_pole.setdefault(pid, []).append(pt)
    for pid, pt in puzzlets:
        seeds_by_pole.setdefault(pid, []).append(pt)

    seeds = [pt for _, pt in poles] + [pt for _, pt in puzzlets]
    hull = MultiPoint(seeds).convex_hull

    units, unit_home = build_units(blocks, poles, hull)
    seeded = sum(1 for h in unit_home if h is not None)
    print(f"{len(units)} units ({seeded} pole-seeded)", file=sys.stderr)

    owner = assign(units, unit_home, poles)
    print(f"{len(owner)} units assigned to {len(set(owner.values()))} poles",
          file=sys.stderr)

    fc = dissolve(units, owner, seeds_by_pole, args.max_reach_m)
    json.dump(fc, open(args.out, "w"))
    print(f"Wrote {args.out} — {len(fc['features'])} territories",
          file=sys.stderr)


if __name__ == "__main__":
    main()
