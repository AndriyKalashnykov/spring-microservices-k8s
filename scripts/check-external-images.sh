#!/usr/bin/env bash
set -uo pipefail

# ---------------------------------------------------------------------------
# External-image health check.
#
# GitHub renders external README images through its camo proxy. When the origin
# (starchart.cc, shields.io, hits.sh, star-history.com, …) returns a non-2xx or
# a non-image body, the image shows as broken on the rendered page. This script
# extracts every EXTERNAL (http/https) image URL from the given markdown files
# and asserts each returns 2xx with an `image/*` content-type.
#
# Caveat: this hits the origin directly. GitHub's camo proxy uses shared IPs and
# may be rate-limited differently, so a green run here does not guarantee camo
# will render every image on every view — but a RED run reliably means the image
# is broken for everyone (4xx/5xx, DNS failure, or wrong content-type). That is
# exactly the failure that took down the "Stargazers over time" chart
# (starchart.cc → 400 "rate limited").
#
# Local committed images (relative paths) are NOT checked here — the PlantUML
# drift gate (`make diagrams-check`) covers those.
# ---------------------------------------------------------------------------

# Tunables (externalized per configuration rules; `?=`-style env fallback).
CURL_MAX_TIME_SECONDS="${CURL_MAX_TIME_SECONDS:-20}"
CURL_RETRIES="${CURL_RETRIES:-2}"

# Files to scan default to README.md; override by passing paths as args.
FILES=("$@")
if [ "${#FILES[@]}" -eq 0 ]; then
  FILES=("README.md")
fi

# Extract external image URLs from markdown:
#   1. Markdown image syntax:  ![alt](https://host/path)
#   2. HTML <img src="https://host/path">
extract_urls() {
  local f="$1"
  [ -f "$f" ] || return 0
  # markdown ![..](url)
  grep -oE '!\[[^]]*\]\((https?://[^)]+)\)' "$f" \
    | sed -E 's/^!\[[^]]*\]\((https?:\/\/[^)]+)\)$/\1/'
  # html <img ... src="url">
  grep -oE '<img[^>]+src="https?://[^"]+"' "$f" \
    | sed -E 's/.*src="(https?:\/\/[^"]+)".*/\1/'
}

mapfile -t URLS < <(for f in "${FILES[@]}"; do extract_urls "$f"; done | sort -u)

if [ "${#URLS[@]}" -eq 0 ]; then
  echo "No external image URLs found in: ${FILES[*]}"
  exit 0
fi

echo "Checking ${#URLS[@]} external image URL(s) in: ${FILES[*]}"
echo

fail=0
for url in "${URLS[@]}"; do
  # -L follow redirects; capture HTTP code and content-type in one request.
  read -r code ctype < <(curl -sS -L \
    --retry "$CURL_RETRIES" --max-time "$CURL_MAX_TIME_SECONDS" \
    -o /dev/null -w '%{http_code} %{content_type}' "$url" 2>/dev/null || echo "000 -")

  if [ "${code:0:1}" = "2" ] && printf '%s' "$ctype" | grep -qiE '^image/'; then
    printf '  OK   [%s] %s  %s\n' "$code" "$ctype" "$url"
  else
    printf '  FAIL [%s] %s  %s\n' "$code" "${ctype:--}" "$url"
    fail=1
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "ERROR: one or more external images are broken (non-2xx or non-image body)."
  echo "       These render as broken images on github.com. Fix the URL or switch provider."
  exit 1
fi
echo "All external images resolve to an image/* body."
