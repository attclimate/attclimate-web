# Map page assets

- `data/posterior_summary.csv` — **real data**, delivered by Jordi Mas: the Bayesian
  ordinal IRT model's posterior summary (country, mean, lower/upper 95% credible
  interval), one row per country, no year dimension yet (cross-sectional snapshot).
- `data/build_irt_data.R` — converts `posterior_summary.csv` into
  `data/country_scores.csv` (adds an ISO3 code per country, via the `countrycode`
  package; Kosovo is hand-mapped to "KOS" to match Plotly's basemap / our own
  `country_bounds.csv`, since it has no official ISO 3166-1 code).
- `data/country_bounds.csv` — country zoom bounding boxes (from `rnaturalearth`,
  scale 50), restricted to each country's "mainland" polygon plus any part within
  ~800km of it (so e.g. France zooms to mainland + Corsica, not its overseas
  territories). Regenerate via `rebuild_country_bounds()` in `build_map.R` if a
  country is ever missing or the mainland-detection heuristic misfires.
- `widgets/climate_support_map.html` (+ `widgets/lib/`) — the pre-rendered Plotly
  choropleth embedded via `<iframe>` in `map.qmd`. Rendered locally with R/plotly
  (`map/data/build_map.R`) rather than as a Quarto/CI code chunk, so the site's
  GitHub Actions build does not need any new R package dependencies. Features:
  - Diverging colour scale (RdBu) centred on 0, matching the IRT model's latent
    scale (can be negative or positive) — not the old 0–1 proxy scale.
  - Hover a country for its score and 95% credible interval.
  - A search box (with autocomplete) to jump straight to a country by name.
  - Click a country (or search) to zoom in, highlight it with a bold outline, and
    open an 80%-opaque popup with its score + credible interval as text (no time
    series yet — the dataset is a single snapshot). Click again / ✕ to close.
  - A brief "Loading map…" overlay while the initial Plotly figure renders.
  - The embedding `<iframe>` in `map.qmd` uses a responsive height
    (`min(70vh, 680px)`, floor 420px) instead of a fixed pixel height.

## Retired for now (not in this build, and not tracked in git — see .gitignore)

An earlier iteration read individual-level raw responses (`data/ccdata_long.rds`,
137MB, kept locally only) and computed a simplified proxy index (weighted mean +
empirical direction correction). That approach produced visibly unstable year-to-year
scores for countries with only 2-3 survey items available in a given year (e.g. Spain
swinging from 0.51 to 0.99 between adjacent survey waves) — not a bug, just too little
item overlap for a naive average to be reliable. That's exactly the sparsity problem
the paper's real Bayesian IRT model (now delivered, see above) is designed to solve,
so the proxy approach (`build_real_data.R`, also gitignored) was dropped in favour of
waiting for real model output. A "dimension" breakdown (problem perception, government
action, etc., from `map/codi_jerarquic.xlsx`) and a longitudinal/animated view were
also built against mock data at one point but are on hold until Jordi delivers
year-resolved and/or per-dimension IRT estimates.

## Updating with new/refined data

1. Replace `data/posterior_summary.csv` with the updated posterior summary.
2. Re-run `data/build_irt_data.R` then `data/build_map.R` to regenerate
   `widgets/climate_support_map.html`.
3. Commit and push — the GitHub Actions workflow republishes the static site as usual.
