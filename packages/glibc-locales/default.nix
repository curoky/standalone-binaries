# glibcLocales — selected locale data only.
#
# Why local:
# 1. The standalone product needs locale data but not the full generated locale
#    archive shipped by the upstream default.
# 2. Disable `allLocales` so only the configured subset enters the artifact.
#
# This is intentional output selection, not an upstream regression.
{ glibcLocales }:

glibcLocales.override {
  allLocales = false;
}
