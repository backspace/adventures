# Experimental assets

## `blocks.geojson` — street-aware territory (experiment)

Drop a `blocks.geojson` here to switch captured-territory shapes from the
abstract Voronoi cells to **city blocks** that follow the street grid. The map
picks it up automatically on the next build; remove the file to revert to
Voronoi. Nothing else is gated — presence of the file *is* the toggle.

Generate it for the venue with:

```
python3 tool/territory/generate_blocks.py \
  --bbox <south> <west> <north> <east> \
  --out assets/experimental/blocks.geojson
```

(see `tool/territory/README.md` for details — needs `requests` + `shapely`.)

Design + rationale:
`~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md`

The file is intentionally gitignored-by-convention here (it's venue data, and
can be large); commit it deliberately if you want it in a build.
