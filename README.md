# Argentina Oil Value Chain — Serverless ELT

🇬🇧 English | [🇦🇷 Español](LEEME.md)

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![dbt](https://img.shields.io/badge/dbt--core-1.7.9-FF694B?logo=dbt&logoColor=white)
![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-4285F4?logo=looker&logoColor=white)

Serverless ELT pipeline integrating four data sources across Argentina's oil
value chain: crude oil production by province and by company (upstream,
monthly), pump prices (downstream, snapshot + historical), and the
international Brent price (FRED).

**Live dashboard:** https://datastudio.google.com/reporting/acb3c54c-6361-470b-8e04-56ea25c7b775

## What the dashboard shows

- **Page 1 — National & Provincial Production**: national production trend,
  provincial breakdown (stacked area, donut, ranking), with Neuquén
  (Vaca Muerta) accounting for ~69% of national output.
- **Page 2 — Production vs. International Price**: Brent spot and Nafta
  Súper scorecards with year-over-year variation, a scatter plot testing
  correlation between Brent and national production (finding: no clear
  monthly correlation, but converging long-term trend), base-100 indexed
  lines, and two gauges showing each series' current position within its
  own 2009–2026 historical range.
- **Page 3 — Pump Prices**: fuel-type selector (Nafta Súper, Nafta Premium,
  Gasoil Grado 2/3, GNC), national average/min/max scorecards, a choropleth
  map by province, and price rankings by province and by brand (bandera).

## Stack

| Layer | Technology |
|---|---|
| Extraction | Python 3.13 (`requests`, `google-cloud-bigquery`) |
| Orchestration | GitHub Actions (cron, daily, Mon-Fri, + manual trigger) |
| Storage & compute | BigQuery (`raw_petroleo`, `analytics_petroleo`, region US) |
| Transformation | dbt-core 1.7.9 + dbt-bigquery + dbt_utils |
| Visualization | Looker Studio |

## Data sources

- **Production by province** — Secretaría de Energía (monthly, since 2009).
  Excludes the "Estado Nacional" aggregate row to avoid double-counting.
- **Production by company** — same source/pattern as above, ~12,600 rows.
  YPF accounts for roughly 40-45% of national output.
- **Pump prices (current snapshot)** — Secretaría de Energía, Resolución
  314/2016, ~4,626 stations, ~36,700 rows. Grain: station × product ×
  time-of-day rate × effective date.
- **Historical pump prices** — same source, one-time backfill (~3.36M rows,
  738 MB), *not* part of the daily pipeline; loaded manually once via
  `cargar_historico_precios.py`.
- **Brent crude (FRED, DCOILBRENTEU)** — daily since 1987, USD/barrel.
  Requires a `User-Agent` header; times out intermittently from GitHub
  Actions (works fine locally), so this step runs with `continue-on-error:
  true`.

## Architecture

```
Extractors (Python)
        ↓
BigQuery — raw_petroleo (raw data, as received from source)
        ↓
dbt — staging (cleaning and typing)
        ↓
dbt — marts (fct_produccion, fct_produccion_empresa, fct_precios_surtidor,
              fct_nafta_mensual, fct_brent_actual, fct_brent_mensual,
              fct_comparativa_mensual, fct_indices_comparativos,
              fct_posicion_historica)
        ↓
Looker Studio (dashboard)
```

`fct_comparativa_mensual` is a full outer join of production, Brent, and
Nafta by period — the backbone for Page 2's cross-source analysis.
`fct_indices_comparativos` builds base-100 indices (Jan-2009) for Brent and
national production, valid because both series have comparable growth
scales. `fct_posicion_historica` computes each series' current value as a
percentage of its own historical min-max range, feeding the two gauges on
Page 2.

## On data freshness — read this before trusting "today's" Brent price

The pipeline runs **once a day**, Monday through Friday, at 11:17 ART. This
matters most for the Brent scorecard, for three stacked reasons:

1. **Pipeline cadence**: only one run per day, not several — unlike a
   truly real-time feed.
2. **Source lag**: FRED itself publishes Brent with a 1-4 day delay; it is
   not a live tick.
3. **Fault tolerance**: the Brent extractor step is intentionally set to
   `continue-on-error: true` because it occasionally times out when run
   from GitHub Actions (it works reliably from a local machine). If it
   fails on a given day, that day's Brent value simply doesn't update —
   there's no automatic retry until the next scheduled run.

In the worst case (a Friday failure), the Brent figure shown on the
dashboard could be several days old before self-correcting on the next
successful run. This is a known, accepted trade-off for a portfolio-scale
project — not a bug.

Production and pump-price data follow their own source publication
schedules (monthly for production, with the latest month often arriving
partial and flagged as such; near-real-time for pump prices, subject to
each station's own reporting cadence).

## Notable design decisions

- **Streak-based variation calculation**: percentage variation is computed
  against the last value from a genuinely different streak (via a running
  `SUM()`-based `streak_id`), not against the previous calendar day. This
  avoids showing 0.00% after two or more flat days in a row.
- **Base-100 indices used selectively**: `fct_indices_comparativos`
  (production vs. Brent) is valid and used on the dashboard because both
  series have comparable growth magnitudes. A similar index between Nafta
  (ARS, inflation-affected) and Brent (USD) was built and tested
  (`fct_indices_nafta_brent`) but deliberately **not** used — the resulting
  scale mismatch (index ~26,000 vs. ~240 over the same period) made it
  mathematically correct but visually meaningless. The model remains in the
  repo as documented dead code rather than being silently deleted.
- **Gauges avoid negative-value metrics**: Looker Studio's gauge minimum
  axis doesn't accept negative values, so year-over-year variation (which
  can go negative) was never used for gauges. Instead, gauges show each
  series' percentage position within its own historical min-max range —
  always non-negative by construction.
- **Station coordinate filtering**: 26 rows with null latitude/longitude
  were excluded from `fct_precios_surtidor` to support the map on Page 3.
  A small number of remaining stations may have coordinates that fall just
  across a neighboring province's border relative to their declared
  `provincia` field — this would require province boundary polygons (a 5th
  data source) to fully correct, which was evaluated and intentionally
  deferred to keep the project's scope in check.

## Running it locally

Requires Python 3.13, a GCP service account with BigQuery permissions, and
dbt-core.

```bash
git clone https://github.com/bloiselautaro/portfolio-petroleo-argentina.git
cd portfolio-petroleo-argentina
pip install google-cloud-bigquery requests "dbt-core==1.7.9" dbt-bigquery "protobuf<5,>=4.25.3"

# Run the main extractors
cd etl
python extractor_produccion.py
python extractor_produccion_empresa.py
python extractor_precios.py
python extractor_brent.py

# Run the dbt transformations
cd ../dbt_project/petroleo_ar
dbt deps
dbt run
dbt test
```

The one-time historical price backfill (`etl/cargar_historico_precios.py`,
~738 MB) is intentionally excluded from the steps above — it's meant to run
once, manually, not as part of routine pipeline execution.

## Known limitations

- Brent price freshness depends on pipeline cadence, source lag, and
  extractor fault tolerance combined — see "On data freshness" above.
- A currency-conversion source (exchange rate, to compare Nafta in USD
  against Brent) was evaluated and explicitly **not** added, to keep the
  project scope to its four confirmed sources.
- Station geolocation may not perfectly match declared province for a small
  subset of records; see "Notable design decisions" above.
- The pipeline depends on the availability and publication lag of each
  public source, which is outside this project's control.
