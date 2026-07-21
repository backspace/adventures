# Street-aware territory — block generator

Offline tool for the experiment that makes captured-territory shapes follow the
street grid instead of the abstract Voronoi cells. See the design doc:
`~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md`.

`generate_blocks.py` fetches the venue's road network from OpenStreetMap,
polygonizes it into city blocks, and writes the GeoJSON the app reads at
`assets/experimental/blocks.geojson`. It runs on your machine — the app never
touches OSM at runtime.

## Setup

```
pip install requests shapely
```

## Two steps

**1. Blocks from OSM** (`generate_blocks.py`) — a complete tiling of the play
area, venue-static:

```
cd landgrab_app
python3 tool/territory/generate_blocks.py \
  --bbox 49.8878 -97.1466 49.9047 -97.1237 \
  --out assets/experimental/blocks.geojson
```

**2. Per-pole territory** (`assign_territory.py`) — assigns every block to a
pole and dissolves each pole's blocks into one contiguous shape, so the app has
a single authoritative polygon per pole (no internal lines, no gaps, tap always
matches colour). Needs pole/puzzlet positions — dump them from the DB first:

```
# poles.geojson  (properties.id)  and  puzzlet_points.geojson (properties.pole_id)
# — see the psql dumps used to create them; both are gitignored (local DB data).

pip install shapely
python3 tool/territory/assign_territory.py \
  --blocks   assets/experimental/blocks.geojson \
  --poles    assets/experimental/poles.geojson \
  --puzzlets assets/experimental/puzzlet_points.geojson \
  --out      assets/experimental/territory.geojson
```

Rebuild. The map prefers `territory.geojson` (pre-dissolved) → else
`blocks.geojson` (live assignment) → else Voronoi. Delete the files to step
back down. Re-run step 2 whenever poles/puzzlets move; re-run step 1 only when
the venue/bbox changes.

Assignment is a multi-source Dijkstra over the block-adjacency graph (each
block → nearest pole by graph distance), so every pole's region is connected by
construction — contiguity guaranteed. Any block holding **more than one pole**
(a shared block or a big superblock) is first split by a Voronoi of those
poles, so each pole gets its own slice — no captured pole is left without a
zone, and a block with three poles in it splits three ways. This is the local
stand-in for the eventual server-side step; `assign_territory.py` reads only
geometry files (no DB) so the logic ports straight over.

## Notes

- **Re-run when poles move or the venue changes.** Blocks are static for a
  fixed venue; the app assigns each block to its nearest pole at load.
- **The river is a boundary.** Water bodies (`natural=water`, `waterway=
  riverbank`) are fetched too: they *close* blocks a street leaves open on the
  water side (the bank becomes the fourth edge) and *clip* any block back to
  the shore. Pass `--no-river` for streets only.
- **Parks/landuse become blocks.** `leisure` (park, garden, recreation,
  common…) and open `landuse` polygons are fetched and added as blocks, so land
  the street grid doesn't enclose — riverfront green, plazas — belongs to a
  zone instead of reading as a blank gap (and a pole standing in it finally
  owns the ground it's on). Parks are dry land and win over water (OSM often
  draws the river onto the shore over a riverfront park — clipping parks to
  water ate their near-shore edge); they're only carved off the street-blocks
  so they fill genuine gaps. `--no-parks` to skip. *Depends on the venue's
  parks being mapped in OSM* — if a riverfront still comes up blank, its land
  isn't tagged as open space upstream.
- **Alleys subdivide blocks.** `--alleys` (default on) pulls in `service=alley`
  ways so big blocks break into building-scale parcels and poles lean far less
  on straight Voronoi splits. `--no-alleys` for arterials only.
- **Complete tiling — no gaps.** All boundaries (streets, alleys, river edge,
  park edges) plus the bbox rectangle are polygonized together, so faces tile
  the whole box with no voids between them. (Overlaying street faces and park
  polygons separately used to leave gaps wherever a park edge didn't meet a
  road centreline — e.g. around a roundabout.) Faces are kept unless they're
  open river (and not a park).
- **Slivers get merged, not shown.** Thin faces roundabouts and Y-junctions
  leave (e.g. the Waterfront Drive circle island) are folded into their largest
  neighbour rather than reading as a micro-zone. Tune with `--merge-below-m2`
  (default 500; raise to ~1000 if a traffic circle persists); truly isolated
  bits below `--min-area-m2` (default 60) drop.
- **Close poles** (the case to watch): each pole is tied to the block it stands
  in (else its nearest block). When two owned poles share a block, the block is
  **split between them along their bisector** — no discs. Tune `maxAssignMeters`
  in `lib/widgets/block_territory_layer.dart`.
- **`--highways`** controls what counts as a street. The default follows real
  roads (drops footways/paths/service); widen it if the venue's paths matter.
- Keep the bbox tight — smaller is faster and yields cleaner blocks.

## Caching

Raw OSM fetches (roads, water) are cached under `tool/territory/.cache`
(gitignored), keyed by bbox + fetch params. So re-running to tune
`--min-area-m2`, `--merge-below-m2`, or `--alleys` is instant and doesn't touch
OSM again. Pass `--refresh` to force a live re-fetch (e.g. after OSM edits), or
`--cache-dir ''` to disable caching.

## Troubleshooting

- **`406 Not Acceptable`** from `overpass-api.de` — its WAF rejects the default
  request. The script already sends a real User-Agent and falls through to
  mirrors; if all fail, pass your own: `--endpoint https://overpass.kumi.systems/api/interpreter`.
- **Timeout / 429** — the public instances are rate-limited; wait a minute, or
  use a different `--endpoint`.
