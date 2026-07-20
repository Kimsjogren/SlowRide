#!/bin/bash
# Merge all individual country PBF files into a single file for Valhalla.
# This avoids the known multi-extract tile-build crash.
#
# Usage: Run on the server before starting Valhalla, or mount as entrypoint.
#   ./merge_pbf.sh /path/to/custom_files
#
# Requires: osmium-tool (apt install osmium-tool)

set -euo pipefail

DATA_DIR="${1:-/custom_files}"
MERGED="$DATA_DIR/merged.osm.pbf"

PBF_FILES=(
  "$DATA_DIR/denmark-latest.osm.pbf"
  "$DATA_DIR/finland-latest.osm.pbf"
  "$DATA_DIR/france-latest.osm.pbf"
  "$DATA_DIR/great-britain-latest.osm.pbf"
  "$DATA_DIR/italy-latest.osm.pbf"
  "$DATA_DIR/norway-latest.osm.pbf"
  "$DATA_DIR/spain-latest.osm.pbf"
  "$DATA_DIR/sweden-latest.osm.pbf"
)

# Check if merged file already exists and is newer than all inputs.
if [ -f "$MERGED" ]; then
  needs_rebuild=false
  for pbf in "${PBF_FILES[@]}"; do
    if [ -f "$pbf" ] && [ "$pbf" -nt "$MERGED" ]; then
      needs_rebuild=true
      break
    fi
  done
  if [ "$needs_rebuild" = false ]; then
    echo "INFO: merged.osm.pbf is up-to-date, skipping merge."
    exit 0
  fi
fi

# Collect only files that exist.
existing=()
for pbf in "${PBF_FILES[@]}"; do
  if [ -f "$pbf" ]; then
    existing+=("$pbf")
  else
    echo "WARNING: $pbf not found, skipping."
  fi
done

if [ ${#existing[@]} -eq 0 ]; then
  echo "ERROR: No PBF files found in $DATA_DIR"
  exit 1
fi

echo "INFO: Merging ${#existing[@]} PBF files into $MERGED ..."
osmium merge "${existing[@]}" -o "$MERGED" --overwrite
echo "INFO: Merge complete ($(du -h "$MERGED" | cut -f1))."
