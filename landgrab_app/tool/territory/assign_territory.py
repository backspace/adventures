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
    """Returns (polys, open_flags) — open_flags[i] is True for open-space
    (park) faces, which territory may flood into to reach the riverbank."""
    from shapely.geometry import shape
    out, opens = [], []
    for f in json.load(open(path)).get("features", []):
        g = shape(f["geometry"])
        is_open = bool((f.get("properties") or {}).get("open"))
        for poly in (g.geoms if g.geom_type == "MultiPolygon" else [g]):
            if poly.is_valid and not poly.is_empty:
                out.append(poly)
                opens.append(is_open)
    return out, opens


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


def build_units(blocks, poles, hull, seeds=(), reach_m=0.0, block_open=None):
    """Turn blocks into assignment *units*, splitting any block that holds more
    than one pole among those poles — so every pole gets its own slice of a
    shared/superblock instead of one pole taking the whole thing (which left
    the others with no zone). Returns (unit_geoms, unit_home) where
    unit_home[i] is the pole id that owns unit i outright, or None (an empty
    unit to be filled)."""
    from collections import defaultdict
    from shapely.ops import unary_union

    in_hull = [i for i, b in enumerate(blocks)
               if hull.contains(b.representative_point())]

    # The units to assign: the in-hull blocks, plus any block a pole actually
    # stands in (added below). Kept as a set so a pole's own block joins in even
    # when it sits outside the seed hull.
    candidate = set(in_hull)

    cents = {i: blocks[i].representative_point() for i in candidate}

    # Each pole → the block it stands in, else its nearest in-hull block. The
    # containment search spans ALL blocks (not just in_hull): an edge pole whose
    # block sits mostly outside the seed hull would otherwise get tied to the
    # nearest in-hull block across a street and end up OUTSIDE its own zone.
    # Adding its true block as a unit anchors the zone on the pole; the adjacent
    # in-hull block then flows to the same pole via Dijkstra (blocks share the
    # street centreline, so they're neighbours), so the zone reaches across.
    poles_in = defaultdict(list)
    home_blocks = set()
    for pid, pt in poles:
        home = next((i for i, b in enumerate(blocks) if b.contains(pt)), None)
        if home is not None:
            candidate.add(home)
            home_blocks.add(home)
        elif in_hull:
            home = min(in_hull, key=lambda i: _metres(cents[i], pt))
        if home is not None:
            poles_in[home].append((pid, pt))

    # (0) Near-coincident poles: two real poles a metre or two apart share one
    # block, and a Voronoi split hands one a degenerate sliver (0112286 got a
    # 233 m² triangle beside 2117940, 1.5 m away). The poles are physical and
    # can't be moved. Keep the split so each pole owns the triangle its own dot
    # sits in, and additionally hand the pole nearest the biggest adjacent block
    # that block — its triangle then extends across the shared street edge into
    # the block next door (0112286's triangle grows west toward Adelaide),
    # giving it a real zone while its dot stays inside.
    from shapely.ops import nearest_points
    NEAR_M = 15.0
    for h, here in list(poles_in.items()):
        if len(here) < 2:
            continue
        pts = [pt for _, pt in here]
        if max(_metres(a, b) for a in pts for b in pts) > NEAR_M:
            continue
        nbrs = [j for j, b in enumerate(blocks)
                if j != h and j not in poles_in and blocks[h].intersects(b)]
        if not nbrs:
            continue
        big = max(nbrs, key=lambda j: blocks[j].area)
        spiller = min(here, key=lambda pp: _metres(
            nearest_points(blocks[big], pp[1])[0], pp[1]))
        candidate.add(big)
        poles_in[big].append(spiller)

    # (1) Admit blocks abutting a pole's own home block but cut off by the hull.
    # An edge pole hemmed onto a thin slice of a shared block spills into the
    # block it's standing next to. One ring around home blocks only.
    for h in home_blocks:
        for j, b in enumerate(blocks):
            if j not in candidate and blocks[h].intersects(b):
                candidate.add(j)

    # (2) Reach-gated flood into connected OPEN-SPACE (park) blocks the hull cut
    # off. The convex hull cuts a straight edge across the play area, stranding
    # a riverfront park that a team can plainly reach — linked to the zone only
    # through a thin road strip — as an unassignable void (Stephen Juba Park).
    # Restricting the flood to parkland means it reaches the river without ever
    # pulling in ordinary peripheral blocks.
    if reach_m and seeds and block_open is not None:
        reachable = [i for i, b in enumerate(blocks)
                     if i not in candidate and block_open[i]
                     and any(_metres(b.representative_point(), s) <= reach_m
                             for s in seeds)]
        changed = True
        while changed and reachable:
            changed = False
            region = unary_union([blocks[i] for i in candidate])
            still = []
            for i in reachable:
                if blocks[i].intersects(region):
                    candidate.add(i)
                    changed = True
                else:
                    still.append(i)
            reachable = still

    geoms, home = [], []
    for i in sorted(candidate):
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


# How far past the reach cap a unit may extend and still be kept whole (so a
# zone ends on a real street edge rather than a disc arc). Roughly one block —
# enough to reach the far side of a normal block, not enough to keep a long
# waterfront/rail strip that runs far beyond the seeds.
_KEEP_MARGIN_M = 90.0


def dissolve(units, owner, seeds_by_pole, reach_m):
    """Union each pole's units, clip to its reach cap, keep the largest
    connected piece, and fill holes that no other zone occupies — one
    contiguous, extent-limited polygon per pole."""
    import math
    from shapely.ops import unary_union
    from shapely.geometry import MultiPolygon, Polygon

    by_pole = {}
    for u, pid in owner.items():
        by_pole.setdefault(pid, []).append(units[u])

    # First pass: each pole's reach-limited, single-piece region (holes intact).
    regions = {}
    for pid, polys in by_pole.items():
        seeds = seeds_by_pole.get(pid)
        if reach_m and seeds:
            cap = _reach_cap(seeds, reach_m)
            # A unit is kept if it reaches into the cap. Then keep it WHOLE when
            # it fits inside a one-block-wider cap (so a zone ends on the block's
            # own street edge, not a circular disc arc), but CLIP the units that
            # run far past the cap to that wider cap. Otherwise a long river/rail
            # strip that merely grazes the disc near the pole gets kept whole and
            # stretches the zone hundreds of metres past its seeds.
            cap_wide = _reach_cap(seeds, reach_m + _KEEP_MARGIN_M)
            kept = []
            for p in polys:
                if not p.intersects(cap):
                    continue
                kept.append(p if cap_wide.contains(p) else p.intersection(cap_wide))
            polys = kept or polys
        merged = unary_union(polys)
        if merged.is_empty:
            continue
        if isinstance(merged, MultiPolygon):
            # Close sub-metre gaps before splitting off pieces. A Voronoi split
            # piece lands a fraction of a millimetre inside its block's true
            # edge (a coordinate round-trip in _split_block), so a pole's
            # triangle can end up hair-separated from the block it extends into
            # (0112286's triangle and the block west toward Adelaide). A tiny
            # close bridges that without merging genuinely separate pieces.
            d = 0.5 / 111000.0
            bridged = merged.buffer(d).buffer(-d)
            # Drop the hairline hole the close leaves where the gap was — the
            # real hole logic below re-derives holes another zone occupies.
            merged = (Polygon(bridged.exterior) if bridged.geom_type == "Polygon"
                      else max(merged.geoms, key=lambda p: p.area))
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
            lat = hole.centroid.y
            hole_m2 = hole.area * (111000.0 * math.cos(lat * math.pi / 180)) * 111000.0
            if hole_m2 < 2.0:
                continue  # hairline/degenerate ring — never a real interior zone
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

    blocks, block_open = load_blocks(args.blocks)
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

    units, unit_home = build_units(blocks, poles, hull, seeds, args.max_reach_m,
                                   block_open)
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
