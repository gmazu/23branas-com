#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

port="${1:-8000}"

echo "Previewing 3Branas-com at http://localhost:${port}"
python3 -m http.server "${port}"
