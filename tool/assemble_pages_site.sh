#!/usr/bin/env bash
# Build one GitHub Pages tree: Flutter web at /, landing page at /lp/, legal at /legal/.
# A later deploy of either half must not wipe the other, so both are always packed together.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <web-build-dir> <landing-docs-dir> <output-dir>" >&2
  exit 1
fi

web_build=$1
landing_docs=$2
output=$3

for required in \
  "$web_build/index.html" \
  "$landing_docs/index.html" \
  "$landing_docs/styles.css" \
  "$landing_docs/.nojekyll" \
  "$landing_docs/robots.txt" \
  "$landing_docs/sitemap.xml" \
  "$landing_docs/legal/terms.html" \
  "$landing_docs/assets/lp/illust-01.svg"
do
  if [ ! -f "$required" ]; then
    echo "missing $required" >&2
    exit 1
  fi
done

if ! grep -q 'base href="/AYG/"' "$web_build/index.html"; then
  echo "web build is not based at /AYG/" >&2
  exit 1
fi

if ! grep -q 'https://naruto-aii.github.io/AYG/lp/' "$landing_docs/index.html"; then
  echo "landing page canonical is not /lp/" >&2
  exit 1
fi

rm -rf "$output"
mkdir -p "$output"
cp -a "$web_build"/. "$output/"
rm -rf "$output/lp"
mkdir -p "$output/lp/assets/lp" "$output/legal"
cp "$landing_docs/index.html" "$landing_docs/styles.css" "$output/lp/"
cp "$landing_docs/assets/lp/"* "$output/lp/assets/lp/"
cp "$landing_docs/legal/"* "$output/legal/"
cp "$landing_docs/.nojekyll" "$landing_docs/robots.txt" "$landing_docs/sitemap.xml" "$output/"

if [ ! -f "$landing_docs/lingo/index.html" ]; then
  echo "missing $landing_docs/lingo/index.html" >&2
  exit 1
fi
rm -rf "$output/lingo"
mkdir -p "$output/lingo"
cp -a "$landing_docs/lingo"/. "$output/lingo/"

# Voxel game lives on main next to docs/. Missing directory is fine for older checkouts.
craft_dir="$(dirname "$landing_docs")/games/craft"
if [ -f "$craft_dir/index.html" ]; then
  mkdir -p "$output/craft"
  cp "$craft_dir/index.html" "$craft_dir/favicon.svg" "$output/craft/"
  cp -a "$craft_dir/css" "$craft_dir/js" "$craft_dir/vendor" "$output/craft/"
fi

if ! cmp -s "$web_build/index.html" "$output/index.html"; then
  echo "web root index.html was replaced" >&2
  exit 1
fi

if ! grep -q 'base href="/AYG/"' "$output/index.html"; then
  echo "web root was replaced" >&2
  exit 1
fi

if grep -q '今日、あと何kcalか' "$output/index.html"; then
  echo "landing page overwrote the web root" >&2
  exit 1
fi

if ! grep -q 'lingo-ui-demo' "$output/lingo/index.html"; then
  echo "lingo demo was not copied" >&2
  exit 1
fi
