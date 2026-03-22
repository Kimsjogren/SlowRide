# Valhalla Routing Server for SlowRide/CruizX

Self-hosted routing server optimized for slow vehicles (A-traktor, Mopedbil, Tractor).

## Why Valhalla?

- **Full control** over routing with custom vehicle profiles
- **No API limits** - unlimited routing requests
- **Offline capable** - works without internet once set up
- **Guaranteed road exclusions** - motorways and ferries properly avoided

## Requirements

- Docker and Docker Compose
- 4-8 GB RAM (for Sweden map)
- ~5 GB disk space
- Windows 11/10, Ubuntu, or macOS

## Quick Start

### 1. Install Docker

**Windows 11:**

1. Download [Docker Desktop](https://docker.com/products/docker-desktop)
2. Install and restart
3. Open Docker Desktop and let it start

**Ubuntu:**

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# Log out and back in
```

### 2. Start Valhalla

```bash
cd docker/valhalla
docker-compose up -d
```

First start downloads Sweden map (~1.5 GB) and builds routing tiles (~30-60 min).

### 3. Check Status

```bash
# Check if running
docker ps

# Check logs
docker logs slowride-valhalla -f

# Test endpoint
curl http://localhost:8002/status
```

### 4. Configure the App

Build the app with Valhalla as the routing provider:

```bash
# From project root
flutter run --dart-define=ROUTING_PROVIDER=valhalla \
            --dart-define=VALHALLA_BASE_URL=http://YOUR_SERVER_IP:8002
```

Or for release builds:

```bash
flutter build apk --dart-define=ROUTING_PROVIDER=valhalla \
                  --dart-define=VALHALLA_BASE_URL=http://192.168.1.100:8002
```

## Adding More Countries

Edit `docker-compose.yml` and add URLs to `tile_urls`:

```yaml
environment:
  - tile_urls=https://download.geofabrik.de/europe/sweden-latest.osm.pbf https://download.geofabrik.de/europe/norway-latest.osm.pbf
```

Available maps: <https://download.geofabrik.de/>

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs slowride-valhalla

# Remove and recreate
docker-compose down
docker-compose up -d
```

### Out of memory during build

Increase memory limit in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 8G
```

### Port 8002 already in use

Change port mapping in `docker-compose.yml`:

```yaml
ports:
  - "8003:8002"  # Use port 8003 instead
```

### Routing returns errors

1. Ensure tiles are built: `curl http://localhost:8002/status`
2. Check the destination is within your map area
3. Verify the API is reachable from the app

## Network Configuration

### Local Network Access

To access from your phone/device on the same network:

1. Find your server's local IP: `ipconfig` (Windows) or `ip addr` (Linux)
2. Use that IP in the app: `http://192.168.1.X:8002`

### Remote Access (VPN recommended)

For access outside your home network:

- Set up a VPN (WireGuard, Tailscale)
- **Avoid** exposing port 8002 directly to the internet

## Vehicle Profiles

The app automatically sends appropriate costing options to Valhalla:

| Vehicle   | Max Speed | Motorway   | Ferry      | Tolls      |
| --------- | --------- | ---------- | ---------- | ---------- |
| A-traktor | 30 km/h   | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| Mopedbil  | 45 km/h   | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| Traktor   | 30 km/h   | ❌ Blocked | ✅ Allowed | ⚠️ Partial |

## Resource Usage

| Map              | RAM (building) | RAM (serving) | Disk   |
| ---------------- | -------------- | ------------- | ------ |
| Sweden           | ~4 GB          | ~1.5 GB       | ~3 GB  |
| Nordic (SE+NO+FI)| ~6 GB          | ~3 GB         | ~8 GB  |
| Europe           | ~16 GB         | ~8 GB         | ~50 GB |

## Updating Map Data

Maps are updated monthly on Geofabrik. To update:

```bash
cd docker/valhalla
docker-compose down
rm -rf data/valhalla_tiles  # Keep downloaded .pbf files
docker-compose up -d
```
