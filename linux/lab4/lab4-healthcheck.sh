#!/usr/bin/env bash
set -euo pipefail

URL="http://127.0.0.1:8000/"

if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL" | grep -q "200"; then
    echo "OK: Service is healthy"
    exit 0
else
    echo "FAIL: Service is down or unreachable"
    exit 1
fi
