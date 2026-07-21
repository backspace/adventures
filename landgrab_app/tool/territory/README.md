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

## Generate

Pick a bounding box tight around the play area (`south west north east`, in
degrees), then:

```
cd landgrab_app
python3 tool/territory/generate_blocks.py \
  --bbox 49.884 -97.140 49.895 -97.120 \
  --out assets/experimental/blocks.geojson
```

Rebuild the app and the map switches to block territory automatically. Delete
`assets/experimental/blocks.geojson` to revert to Voronoi — presence of the
file is the only toggle.

## Notes

- **Re-run when poles move or the venue changes.** Blocks are static for a
  fixed venue; the app assigns each block to its nearest pole at load.
- **The river is a boundary.** Water bodies (`natural=water`, `waterway=
  riverbank`) are fetched too: they *close* blocks a street leaves open on the
  water side (the bank becomes the fourth edge) and *clip* any block back to
  the shore. Pass `--no-river` for streets only.
- **Alleys subdivide blocks.** `--alleys` (default on) also pulls in
  `service=alley` + pedestrian/footway/path ways, so big blocks break into
  building-scale parcels and poles lean far less on straight Voronoi splits.
  `--no-alleys` for arterials only.
- **Slivers get merged, not shown.** Thin faces roundabouts and Y-junctions
  leave (e.g. the Waterfront Drive circle) are folded into their largest
  neighbour rather than reading as a micro-zone. Tune with `--merge-below-m2`
  (default 350); truly isolated bits below `--min-area-m2` (default 60) drop.
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
