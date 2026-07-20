#!/usr/bin/env bash

# Wait for the isolated Italy tile build, validate it, and promote it.
# The previous production container is retained as a stopped rollback target.

set -Eeuo pipefail

BUILDER="slowride-valhalla-italy-builder"
TEST_CONTAINER="slowride-valhalla-italy-test"
PRODUCTION_CONTAINER="slowride-valhalla"
ROLLBACK_CONTAINER="slowride-valhalla-pre-italy"
IMAGE="ghcr.io/gis-ops/docker-valhalla/valhalla:latest"
BUILD_DIR="/home/cruizx/valhalla/data-italy-build"
TEST_PORT="8005"

log() {
  printf '%s %s\n' "$(date --iso-8601=seconds)" "$*"
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" = "true" ]
}

wait_for_status() {
  local url="$1"
  local attempts="${2:-90}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --max-time 5 "$url/status" >/dev/null; then
      return 0
    fi
    sleep 10
  done
  return 1
}

wait_for_port_free() {
  local port="$1"
  local attempts="${2:-60}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if ! ss -ltnH "sport = :$port" | grep -q .; then
      return 0
    fi
    sleep 1
  done
  return 1
}

test_route() {
  local base_url="$1"
  local name="$2"
  local from_lat="$3"
  local from_lon="$4"
  local to_lat="$5"
  local to_lon="$6"
  local response
  response="$(curl -fsS --max-time 120 -X POST "$base_url/route" \
    -H 'Content-Type: application/json' \
    --data "{\"locations\":[{\"lat\":$from_lat,\"lon\":$from_lon},{\"lat\":$to_lat,\"lon\":$to_lon}],\"costing\":\"auto\",\"directions_options\":{\"units\":\"kilometers\",\"language\":\"it-IT\"}}")"
  grep -q '"trip"' <<<"$response"
  log "Route passed: $name"
}

rollback() {
  log "Production validation failed; rolling back."
  docker rm -f "$PRODUCTION_CONTAINER" >/dev/null 2>&1 || true
  if docker inspect "$ROLLBACK_CONTAINER" >/dev/null 2>&1; then
    docker rename "$ROLLBACK_CONTAINER" "$PRODUCTION_CONTAINER"
    docker start "$PRODUCTION_CONTAINER" >/dev/null
  fi
}

log "Waiting for $BUILDER."
while container_running "$BUILDER"; do
  sleep 60
done

builder_exit="$(docker inspect -f '{{.State.ExitCode}}' "$BUILDER")"
if [ "$builder_exit" != "0" ]; then
  log "Builder failed with exit code $builder_exit; production unchanged."
  exit 1
fi

test -s "$BUILD_DIR/valhalla_tiles.tar"
log "Tile archive completed: $(du -h "$BUILD_DIR/valhalla_tiles.tar" | cut -f1)."

docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
docker run -d \
  --name "$TEST_CONTAINER" \
  --cpus=2 \
  --memory=8g \
  -p "127.0.0.1:$TEST_PORT:8002" \
  -v "$BUILD_DIR:/custom_files" \
  -e use_tiles_ignore_pbf=True \
  -e force_rebuild=False \
  -e serve_tiles=True \
  -e server_threads=2 \
  "$IMAGE" >/dev/null

wait_for_status "http://127.0.0.1:$TEST_PORT"
test_route "http://127.0.0.1:$TEST_PORT" "Rome-Florence" 41.9028 12.4964 43.7696 11.2558
test_route "http://127.0.0.1:$TEST_PORT" "Nice-Genoa" 43.7102 7.2620 44.4056 8.9463
docker rm -f "$TEST_CONTAINER" >/dev/null

if docker inspect "$ROLLBACK_CONTAINER" >/dev/null 2>&1; then
  log "$ROLLBACK_CONTAINER already exists; refusing to overwrite rollback state."
  exit 1
fi

log "Validation passed; promoting Italy tiles."
docker stop "$PRODUCTION_CONTAINER" >/dev/null
docker rename "$PRODUCTION_CONTAINER" "$ROLLBACK_CONTAINER"

if ! wait_for_port_free 8002; then
  log "Port 8002 was not released after stopping production."
  rollback
  exit 1
fi

if ! docker run -d \
  --name "$PRODUCTION_CONTAINER" \
  --restart unless-stopped \
  --cpus=2 \
  --memory=24g \
  -p 8002:8002 \
  -v "$BUILD_DIR:/custom_files" \
  -e use_tiles_ignore_pbf=True \
  -e force_rebuild=False \
  -e serve_tiles=True \
  -e server_threads=2 \
  "$IMAGE" >/dev/null; then
  rollback
  exit 1
fi

if ! wait_for_status "http://127.0.0.1:8002"; then
  rollback
  exit 1
fi

if ! test_route "http://127.0.0.1:8002" "Production Rome-Florence" 41.9028 12.4964 43.7696 11.2558 || \
   ! test_route "http://127.0.0.1:8002" "Production Nice-Genoa" 43.7102 7.2620 44.4056 8.9463; then
  rollback
  exit 1
fi

log "DEPLOYMENT_SUCCESS: Italy tiles are active; rollback container retained as $ROLLBACK_CONTAINER."
