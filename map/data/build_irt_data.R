# Converts the real Bayesian IRT posterior summary (posterior_summary.csv,
# delivered by Jordi Mas) into map/data/country_scores.csv: one row per
# country with an ISO3 code, ready for the choropleth.
#
# posterior_summary.csv columns: country (CLDR-style English name), mean
# (posterior mean of the latent climate-support trait), lower/upper (95%
# credible interval bounds). This is a single cross-sectional snapshot --
# no year column -- so the Map page shows one map, no time slider.
#
# Run with the working directory set to the site's project root.

suppressPackageStartupMessages(library(countrycode))

d <- read.csv("map/data/posterior_summary.csv", encoding = "UTF-8")

# Kosovo isn't in ISO 3166-1; use "KOS", the code Natural Earth (and our own
# map/data/country_bounds.csv) assigns it, so it matches Plotly's basemap.
d$iso3 <- countrycode(d$country, origin = "country.name", destination = "iso3c",
                       custom_match = c("Kosovo" = "KOS"))

if (any(is.na(d$iso3))) {
  warning("Unmatched countries (dropped): ", paste(d$country[is.na(d$iso3)], collapse = ", "))
  d <- d[!is.na(d$iso3), ]
}

d <- d[, c("iso3", "country", "mean", "lower", "upper")]
write.csv(d, "map/data/country_scores.csv", row.names = FALSE)
cat(sprintf("Saved map/data/country_scores.csv: %d countries\n", nrow(d)))
