#!/usr/bin/env bash

#####################################################
# Used by git hub actions to create the public feeds
# DO NOT MOVE OR RENAME
#####################################################

set -euo pipefail

echo "======================================="
echo " Validating feeds"
echo "======================================="

if [ ! -d "feeds" ]; then
    echo "ERROR: feeds/ directory not found"
    exit 1
fi

if [ -z "$(ls -A feeds 2>/dev/null)" ]; then
    echo "ERROR: feeds/ directory is empty"
    exit 1
fi

echo "Feeds OK"
echo "======================================="
echo "Creating latest feed package"
echo "======================================="

function create_latest_feed_package() {
	local feed="${1}"
    local newest_vespera_ipk="$(find feeds/"${feed}"/vespera -type f -name 'vespera*.ipk' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"

    if [ -n "$newest_vespera_ipk" ]; then
            latest_copy_path="$(dirname "$newest_vespera_ipk")/vespera-latest.ipk"
            cp -f "$newest_vespera_ipk" "$latest_copy_path"
			echo "Created latest package copy: feeds/${feed}/$latest_copy_path"
	else
			echo "No vespera*.ipk package found under feeds/${feed}"
	fi
}

create_latest_feed_package "release"
create_latest_feed_package "develop"

echo "======================================="
echo " Generating feed HTML indexes"
echo "======================================="

# We will generate HTML directly inside feeds first
# (temporary stage before Jekyll copy)

html_head='
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Index</title>
<style>
:root {
  color-scheme: light dark;
  --background: #ffffff;
  --foreground: #1f2328;
  --muted: #59636e;
  --border: #d1d9e0;
  --hover: #f6f8fa;
  --link: #0969da;
}
@media (prefers-color-scheme: dark) {
  :root {
    --background: #0d1117;
    --foreground: #e6edf3;
    --muted: #9198a1;
    --border: #30363d;
    --hover: #161b22;
    --link: #58a6ff;
  }
}
* { box-sizing: border-box; }
body {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px;
  background: var(--background);
  color: var(--foreground);
  font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
h1 { margin: 0 0 20px; font-size: 24px; overflow-wrap: anywhere; }
ul { list-style: none; padding: 0; margin: 0; border: 1px solid var(--border); border-radius: 6px; }
li { display: grid; grid-template-columns: minmax(0, 1fr) 20ch 10ch; gap: 16px; padding: 10px 16px; }
li + li { border-top: 1px solid var(--border); }
li:hover { background: var(--hover); }
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
a:focus-visible { outline: 2px solid var(--link); outline-offset: 3px; }
.name { min-width: 0; overflow-wrap: anywhere; }
.mtime, .size { color: var(--muted); font-variant-numeric: tabular-nums; }
.size { text-align: right; }
@media (max-width: 600px) {
  body { padding: 16px; }
  li { grid-template-columns: minmax(0, 1fr) auto; gap: 4px 12px; }
  .name { grid-column: 1 / -1; }
}
</style>
</head>
<body>
'

# Generate index pages inside feeds
find feeds -type d | while read -r dir; do
{
    echo "$html_head"
    echo "<h1>${dir#feeds/}</h1>"
    echo "<ul>"

    parent=$(dirname "$dir")
    if [ -f "$parent/index.html" ]; then
        echo "<li><a href=\"../\">.. Parent Directory</a></li>"
    fi

    for f in "$dir"/*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "index.html" ] && continue

        if [ -f "$f" ]; then
            size=$(stat -c %s "$f")
            size=$(numfmt --to=iec --suffix=B "$size")
            folder=""
        else
            size="-"
            folder="/"
        fi

        mtime=$(stat -c %y "$f" | cut -d'.' -f1)

        echo "<li><span class=\"name\"><a href=\"$name\">$name$folder</a></span> \
<span class=\"mtime\">$mtime</span> \
<span class=\"size\">$size</span></li>"
    done

    echo "</ul></body></html>"
} > "$dir/index.html"

done

echo "======================================="
echo " Feed validation and feed index page generation complete "
echo "======================================="
