#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="/opt/lab4-service/html"

mkdir -p "$WEB_ROOT"

if [ ! -f "$WEB_ROOT/index.html" ]; then
    echo "<h1>СЕМЕНОВА</h1>" > "$WEB_ROOT/index.html"
fi


exec python3 -m http.server --directory "$WEB_ROOT" 8000
