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

# Download map extracts (Nordics + France + Spain)
cd data
wget -N https://download.geofabrik.de/europe/sweden-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/norway-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/denmark-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/finland-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/france-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/spain-latest.osm.pbf
wget -N https://download.geofabrik.de/europe/great-britain-latest.osm.pbf

cd ..
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

## Monitoring and Alerts

The compose file already includes:

- a Docker `healthcheck` on `http://localhost:8002/status`
- `restart: unless-stopped`
- `autoheal`, which restarts Valhalla if Docker marks it `unhealthy`

That gives you self-healing, but not a real alarm. For alerts on Ubuntu:

### 1. Make the monitor script executable

```bash
cd docker/valhalla
chmod +x monitor_valhalla.sh
```

### 2. Test it manually

```bash
./monitor_valhalla.sh
```

Optional alert channels:

- `NTFY_TOPIC=my-private-topic ./monitor_valhalla.sh`
- `TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... ./monitor_valhalla.sh`

### 3. Run it every minute with systemd

Create `/etc/systemd/system/valhalla-monitor.service`:

```ini
[Unit]
Description=Monitor SlowRide Valhalla health
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/slowride/docker/valhalla
Environment=STATUS_URL=http://127.0.0.1:8002/status
Environment=CONTAINER_NAME=slowride-valhalla
# Optional:
# Environment=NTFY_TOPIC=your-private-topic
# Environment=TELEGRAM_BOT_TOKEN=123456:abc
# Environment=TELEGRAM_CHAT_ID=123456789
ExecStart=/opt/slowride/docker/valhalla/monitor_valhalla.sh
```

Create `/etc/systemd/system/valhalla-monitor.timer`:

```ini
[Unit]
Description=Run Valhalla monitor every minute

[Timer]
OnBootSec=2m
OnUnitActiveSec=1m
Unit=valhalla-monitor.service

[Install]
WantedBy=timers.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now valhalla-monitor.timer
sudo systemctl list-timers | grep valhalla-monitor
```

### 4. Recommended: external uptime check too

A local alarm won't help if the whole Ubuntu server goes down. Add one external monitor as well:

- Uptime Kuma on another server
- Better Stack
- UptimeRobot

Point it at:

```bash
http://YOUR_SERVER_IP:8002/status
```

Best setup is both:

- local self-healing + local alerts
- external uptime monitor for full server/network outages

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

Add the country PBF in both places:

1. Download the country file to `docker/valhalla/data`.
2. Add `<country>-latest.osm.pbf` to `PBF_FILES` in `merge_pbf.sh`.

Example (Spain):

```bash
cd docker/valhalla/data
wget -N https://download.geofabrik.de/europe/spain-latest.osm.pbf
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
rm -f data/merged.osm.pbf
docker-compose up -d
```

## Side-by-Side Tiles + Gateway (Without Touching Valhalla)

If you want to add map tile serving on the same server without changing the
existing Valhalla service, use the side-by-side compose file.

This keeps Valhalla as-is on port `8002` and adds:

- `tileserver` on `8081` (direct access, optional)
- `nginx` gateway on `8088`
  - `/routing/*` -> Valhalla (`valhalla:8002`)
  - `/tiles/*` -> Tileserver (`tileserver:8080`)

### 1. Add tile data

Put at least one `.mbtiles` file in:

```bash
docker/valhalla/tiles/
```

### 2. Start side-by-side services

From `docker/valhalla`:

```bash
docker compose -f docker-compose.yml -f docker-compose.side-by-side.yml up -d tileserver nginx
```

This does not modify the original `docker-compose.yml` service definitions.

### 3. Verify endpoints

```bash
# Existing Valhalla direct
curl http://localhost:8002/status

# Through gateway
curl http://localhost:8088/status

# Tile service through gateway (example path)
curl -I http://localhost:8088/tiles/
```

### 4. Stop only side-by-side extras

```bash
docker compose -f docker-compose.yml -f docker-compose.side-by-side.yml stop tileserver nginx
```
