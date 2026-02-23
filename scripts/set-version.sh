#!/bin/bash
set -euo pipefail

# Sync version across app and plugin
# Usage: ./scripts/set-version.sh 0.3.0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${1:-}" ]; then
    # Show current version
    CURRENT=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/plugin/plugin.json'))['version'])")
    echo "Current version: $CURRENT"
    echo "Usage: $0 <new-version>"
    exit 0
fi

VERSION="$1"
echo "==> Setting version to $VERSION"

# Update plugin.json
python3 -c "
import json, pathlib
p = pathlib.Path('$REPO_ROOT/plugin/plugin.json')
d = json.loads(p.read_text())
d['version'] = '$VERSION'
p.write_text(json.dumps(d, indent=2) + '\n')
"
echo "    plugin/plugin.json -> $VERSION"

# Update Xcode project (MARKETING_VERSION)
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" \
    "$REPO_ROOT/copilot-island.xcodeproj/project.pbxproj"
echo "    project.pbxproj MARKETING_VERSION -> $VERSION"

echo "==> Done"
