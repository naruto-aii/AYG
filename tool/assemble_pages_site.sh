#!/usr/bin/env bash
# GitHub Pages に置く静的ファイルだけをまとめる。
# /lp/ は紹介、/legal/ は法務、/lingo/ /craft/ /tenshoku/ は既存の静的ページ。
# Flutter の web ビルドは入れない。
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <landing-docs-dir> <output-dir>" >&2
  exit 1
fi

landing_docs="$(cd "$1" && pwd)"
output=$2
repo_root="$(dirname "$landing_docs")"

for required in \
  "$landing_docs/index.html" \
  "$landing_docs/styles.css" \
  "$landing_docs/.nojekyll" \
  "$landing_docs/robots.txt" \
  "$landing_docs/sitemap.xml" \
  "$landing_docs/site-index.html" \
  "$landing_docs/legal/privacy.html" \
  "$landing_docs/legal/terms.html" \
  "$landing_docs/legal/support.html" \
  "$landing_docs/legal/account-deletion.html" \
  "$landing_docs/legal/tokushoho.html" \
  "$landing_docs/legal/index.html" \
  "$landing_docs/legal/legal.css" \
  "$landing_docs/assets/lp/illust-01.svg" \
  "$landing_docs/lingo/index.html"
do
  if [ ! -f "$required" ]; then
    echo "missing $required" >&2
    exit 1
  fi
done

if ! grep -q 'https://naruto-aii.github.io/AYG/lp/' "$landing_docs/index.html"; then
  echo "landing page canonical is not /lp/" >&2
  exit 1
fi

rm -rf "$output"
mkdir -p "$output/lp/assets/lp" "$output/legal" "$output/lingo"
cp "$landing_docs/site-index.html" "$output/index.html"
cp "$landing_docs/index.html" "$landing_docs/styles.css" "$output/lp/"
cp "$landing_docs/assets/lp/"* "$output/lp/assets/lp/"
cp "$landing_docs/legal/"* "$output/legal/"
cp "$landing_docs/.nojekyll" "$landing_docs/robots.txt" "$landing_docs/sitemap.xml" "$output/"
cp -a "$landing_docs/lingo"/. "$output/lingo/"

for legal_file in privacy.html terms.html support.html account-deletion.html tokushoho.html index.html legal.css; do
  if ! cmp -s "$landing_docs/legal/$legal_file" "$output/legal/$legal_file"; then
    echo "legal/$legal_file was changed while copying" >&2
    exit 1
  fi
done

craft_dir="$repo_root/games/craft"
if [ -f "$craft_dir/index.html" ]; then
  mkdir -p "$output/craft"
  cp "$craft_dir/index.html" "$craft_dir/favicon.svg" "$output/craft/"
  cp -a "$craft_dir/css" "$craft_dir/js" "$craft_dir/vendor" "$output/craft/"
fi

tenshoku_dir="$repo_root/games/tenshoku"
if [ -f "$tenshoku_dir/index.html" ]; then
  mkdir -p "$output/tenshoku"
  cp "$tenshoku_dir/index.html" "$tenshoku_dir/favicon.svg" "$output/tenshoku/"
  cp -a "$tenshoku_dir/css" "$tenshoku_dir/js" "$output/tenshoku/"
  if ! grep -q 'tenshoku-quest' "$output/tenshoku/index.html"; then
    echo "tenshoku game was not copied" >&2
    exit 1
  fi
fi

if ! grep -q 'https://naruto-aii.github.io/AYG/lp/' "$output/lp/index.html"; then
  echo "landing page was not copied to /lp/" >&2
  exit 1
fi

if ! grep -q 'lingo-ui-demo' "$output/lingo/index.html"; then
  echo "lingo demo was not copied" >&2
  exit 1
fi

if grep -q 'flutter.js' "$output/index.html" || grep -q 'main.dart.js' "$output/index.html"; then
  echo "flutter web app was published at the site root" >&2
  exit 1
fi

if find "$output" -name 'main.dart.js' -o -name 'flutter.js' -o -name 'flutter_bootstrap.js' | grep -q .; then
  echo "flutter web build was included" >&2
  exit 1
fi
