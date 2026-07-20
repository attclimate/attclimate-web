# Builds the Map page widget (map/widgets/climate_support_map.html) from
# map/data/country_scores.csv -- the real Bayesian IRT posterior summary
# (see build_irt_data.R), one row per country: iso3, country, mean, lower,
# upper (95% credible interval). Single cross-sectional snapshot, no year
# dimension -- the longitudinal view is deferred to a later iteration.
#
# Run with the working directory set to the site's project root.
# Requires: plotly, htmltools, jsonlite.

suppressPackageStartupMessages({
  library(plotly)
  library(htmltools)
  library(jsonlite)
})

dat <- read.csv("map/data/country_scores.csv")
bounds <- read.csv("map/data/country_bounds.csv")

country_names <- setNames(dat$country, dat$iso3)
country_ci <- setNames(
  lapply(seq_len(nrow(dat)), function(i) list(mean = dat$mean[i], lower = dat$lower[i], upper = dat$upper[i])),
  dat$iso3
)
bounds_by_country <- setNames(
  lapply(seq_len(nrow(bounds)), function(i) as.list(bounds[i, c("lon_min", "lon_max", "lat_min", "lat_max")])),
  bounds$iso3
)

zlim <- max(abs(dat$mean))

## ---- main choropleth (diverging scale, centred on 0) ----
map_widget <- plot_ly(
  dat, type = "choropleth", locations = ~iso3, z = ~mean,
  text = ~country, locationmode = "ISO-3",
  colorscale = "RdBu", reversescale = TRUE, zmid = 0, zmin = -zlim, zmax = zlim,
  customdata = ~cbind(lower, upper),
  hovertemplate = paste0(
    "<b>%{text}</b><br>Score: %{z:.2f}",
    "<br>95% CI: [%{customdata[0]:.2f}, %{customdata[1]:.2f}]<extra></extra>"
  ),
  marker = list(line = list(color = "rgba(150,150,150,0.6)", width = 0.5)),
  colorbar = list(title = "Score", len = 0.7)
) %>%
  add_trace(
    type = "choropleth", locations = list(), z = list(),
    colorscale = list(list(0, "rgba(0,0,0,0)"), list(1, "rgba(0,0,0,0)")),
    showscale = FALSE, showlegend = FALSE, hoverinfo = "skip",
    marker = list(line = list(color = "#FF6B00", width = 3))
  ) %>%
  layout(
    geo = list(
      projection = list(type = "natural earth"),
      showframe = FALSE, showcoastlines = FALSE,
      showcountries = TRUE, countrycolor = "rgba(160,160,160,0.6)",
      showland = TRUE, landcolor = "rgba(210,210,210,0.35)",
      bgcolor = "rgba(0,0,0,0)"
    ),
    paper_bgcolor = "rgba(0,0,0,0)",
    margin = list(l = 0, r = 0, t = 10, b = 0),
    font = list(color = "#444444")
  ) %>%
  config(responsive = TRUE) %>%
  htmlwidgets::onRender("
    function(el, x) {
      el.classList.add('climate-geo-plot');
      el.on('plotly_click', function(d) {
        if (!d || !d.points || !d.points.length) return;
        var iso3 = d.points[0].location;
        if (iso3) { climateMapSelectCountry(iso3, el); }
      });
      var loader = document.getElementById('map-loading');
      if (loader) loader.style.display = 'none';
    }
  ")

search_box <- tags$div(
  style = "display:flex; align-items:center; gap:0.5rem; margin-bottom:8px; flex-wrap:wrap;",
  tags$input(
    id = "country-search", list = "country-search-list", type = "search",
    placeholder = "Search a country and press Enter…",
    onkeydown = "if (event.key === 'Enter') climateMapSearchSubmit();",
    style = "padding:4px 8px; border-radius:6px; border:1px solid #99999966; min-width:240px; background:transparent; color:inherit;"
  ),
  tags$datalist(id = "country-search-list")
)

score_caption <- tags$p(
  style = "font-size:0.78rem; opacity:0.7; margin:0 0 8px;",
  "Score: posterior mean of the latent climate-support trait (Bayesian ordinal IRT model). ",
  "Hover a country for its 95% credible interval; grey = no data."
)

## ---- country detail popup (80% opaque, closable; text only -- no time series yet) ----
popup <- tags$div(
  id = "country-popup",
  style = paste(
    "display:none; position:absolute; inset:0; z-index:50;",
    "background:rgba(255,255,255,0.8); border-radius:10px;",
    "padding:1.25rem; box-sizing:border-box;"
  ),
  tags$button(
    "✕", onclick = "climateMapClosePopup()",
    style = paste(
      "position:absolute; top:10px; right:14px; background:none; border:none;",
      "font-size:1.3rem; line-height:1; cursor:pointer; color:#333;"
    )
  ),
  tags$h4(id = "country-popup-title", style = "margin:0 0 0.4rem; color:#222;"),
  tags$p(id = "country-popup-detail", style = "font-size:0.95rem; color:#333;")
)

loading_overlay <- tags$div(
  id = "map-loading",
  style = paste(
    "position:absolute; inset:0; z-index:60; display:flex; align-items:center;",
    "justify-content:center; background:rgba(255,255,255,0.6); font-family:system-ui,sans-serif;",
    "font-size:0.9rem; color:#444;"
  ),
  "Loading map…"
)

script <- tags$script(HTML(paste0("
var climateMapNames = ", jsonlite::toJSON(as.list(country_names), auto_unbox = TRUE), ";
var climateMapCI = ", jsonlite::toJSON(country_ci, auto_unbox = TRUE), ";
var climateMapBounds = ", jsonlite::toJSON(bounds_by_country, auto_unbox = TRUE), ";
var climateMapSelected = null;

(function () {
  var dl = document.getElementById('country-search-list');
  Object.keys(climateMapNames).map(function(k) { return climateMapNames[k]; }).sort().forEach(function(n) {
    var opt = document.createElement('option');
    opt.value = n;
    dl.appendChild(opt);
  });
})();

function climateMapVisiblePane() {
  var pane = document.querySelector('.dim-pane') || document.querySelector('.climate-geo-plot');
  if (pane && pane.classList.contains('climate-geo-plot')) return pane;
  return document.querySelector('.climate-geo-plot');
}

function climateMapSelectCountry(iso3) {
  if (climateMapSelected === iso3) { climateMapClosePopup(); return; }
  climateMapSelected = iso3;
  var el = climateMapVisiblePane();
  var b = climateMapBounds[iso3];
  if (el && b) {
    var padLon = Math.max((b.lon_max - b.lon_min) * 0.3, 3);
    var padLat = Math.max((b.lat_max - b.lat_min) * 0.3, 3);
    Plotly.relayout(el, {
      'geo.lonaxis.range': [b.lon_min - padLon, b.lon_max + padLon],
      'geo.lataxis.range': [b.lat_min - padLat, b.lat_max + padLat]
    });
    Plotly.restyle(el, { 'marker.opacity': 0.3 }, [0]);
    Plotly.restyle(el, { locations: [[iso3]], z: [[1]] }, [1]);
  }
  var ci = climateMapCI[iso3];
  document.getElementById('country-popup-title').textContent = climateMapNames[iso3] || iso3;
  document.getElementById('country-popup-detail').textContent = ci
    ? ('Score: ' + ci.mean.toFixed(2) + '  (95% credible interval: ' + ci.lower.toFixed(2) + ' to ' + ci.upper.toFixed(2) + ')')
    : 'No data for this country.';
  document.getElementById('country-popup').style.display = 'block';
}

function climateMapSearchSubmit() {
  var input = document.getElementById('country-search');
  var name = input.value.trim();
  if (!name) return;
  var iso3 = null;
  Object.keys(climateMapNames).forEach(function(k) {
    if (climateMapNames[k].toLowerCase() === name.toLowerCase()) iso3 = k;
  });
  if (!iso3) return;
  climateMapSelectCountry(iso3);
  input.value = '';
}

function climateMapClosePopup() {
  climateMapSelected = null;
  document.getElementById('country-popup').style.display = 'none';
  document.querySelectorAll('.climate-geo-plot').forEach(function(el) {
    Plotly.relayout(el, { 'geo.lonaxis.range': null, 'geo.lataxis.range': null });
    Plotly.restyle(el, { 'marker.opacity': 1 }, [0]);
    Plotly.restyle(el, { locations: [[]], z: [[]] }, [1]);
  });
}

window.addEventListener('resize', function() {
  document.querySelectorAll('.climate-geo-plot').forEach(function(el) {
    try { Plotly.Plots.resize(el); } catch (e) {}
  });
});
")))

page <- tagList(
  tags$div(style = "font-family: system-ui, sans-serif; position:relative;",
    search_box,
    score_caption,
    tags$div(style = "position:relative;",
      map_widget, popup, loading_overlay
    ),
    script
  )
)

out_file <- "map/widgets/climate_support_map.html"
dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
save_html(browsable(page), out_file, libdir = "lib")
cat("saved widget:", out_file, "\n")
