# LetsYak Calling — Server Setup Guide

This document describes the backend services needed to support LetsYak's
native calling feature. All services run in Docker alongside your existing
Synapse homeserver.

---

## Architecture Overview

```
┌──────────────┐       ┌───────────────┐       ┌──────────────┐
│  LetsYak App │──WSS──│  LiveKit SFU   │──RTP──│   Clients    │
│  (Flutter)   │       │  (port 7880)   │       │              │
└──────┬───────┘       └───────┬────────┘       └──────────────┘
       │                       │
       │ HTTPS                 │ internal
       ▼                       ▼
┌──────────────┐       ┌───────────────┐       ┌──────────────┐
│ lk-jwt-service│      │ LiveKit Egress │◄─────│    Redis     │
│ (port 8080)  │       │ (recording)   │       │  (port 6379) │
└──────┬───────┘       └───────────────┘       └──────────────┘
       │
       │ verify
       ▼
┌──────────────┐
│   Synapse    │
│ homeserver   │
└──────────────┘
```

---

## 1. Docker Compose

Create a `docker-compose.calling.yml` alongside your existing Synapse
compose file:

```yaml
version: "3.8"

services:
  # ─── LiveKit SFU ───────────────────────────────────────────────
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"     # WebSocket / HTTP API
      - "7881:7881"     # RTC (TCP fallback)
      - "50000-50060:50000-50060/udp"  # WebRTC UDP media
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
    command: --config /etc/livekit.yaml
    restart: unless-stopped

  # ─── LiveKit JWT Service (MatrixRTC auth bridge) ───────────────
  # Validates Matrix OpenID tokens and issues LiveKit JWTs
  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    ports:
      - "8080:8080"
    environment:
      - LK_JWT_PORT=8080
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_KEY=your_api_key          # MUST MATCH livekit.yaml
      - LIVEKIT_SECRET=your_api_secret    # MUST MATCH livekit.yaml
      # Synapse homeserver for OpenID token validation
      - LIVEKIT_INSECURE_SKIP_VERIFY_TLS=false
    restart: unless-stopped

  # ─── Redis (required by LiveKit Egress) ────────────────────────
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

  # ─── LiveKit Egress (server-side recording) ────────────────────
  # Optional: Only needed if you want call recording
  livekit-egress:
    image: livekit/egress:latest
    environment:
      - EGRESS_CONFIG_FILE=/etc/egress.yaml
    volumes:
      - ./egress.yaml:/etc/egress.yaml
      - /tmp/livekit-egress:/tmp/livekit-egress
    cap_add:
      - SYS_ADMIN  # needed for Chrome/Chromium headless recording
    restart: unless-stopped
    depends_on:
      - livekit
      - redis
```

---

## 2. LiveKit Configuration

Create `livekit.yaml`:

```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50060
  # Set this to your server's public IP
  # If behind NAT, this must be the external IP
  node_ip: "YOUR_SERVER_PUBLIC_IP"
  use_external_ip: true

keys:
  # Generate these with: docker run --rm livekit/livekit-server generate-keys
  your_api_key: your_api_secret

logging:
  level: info

# TURN/STUN configuration (use your existing Coturn or Synapse's TURN)
turn:
  enabled: true
  domain: turn.maybery.app
  tls_port: 443
  udp_port: 3478
  # If using your own Coturn:
  # external_tls: true
```

### Generating API Keys

```bash
docker run --rm livekit/livekit-server generate-keys
```

This outputs an API key and secret. Use them in both `livekit.yaml` and the
`lk-jwt-service` environment variables.

---

## 3. LiveKit Egress Configuration (Optional)

Create `egress.yaml` for recording support:

```yaml
log_level: info
api_key: your_api_key       # MUST MATCH livekit.yaml
api_secret: your_api_secret # MUST MATCH livekit.yaml
ws_url: ws://livekit:7880

# Redis for job queue
redis:
  address: redis:6379

# Where to store recordings
file_output:
  local:
    - /tmp/livekit-egress

# Optional: S3-compatible storage
# s3:
#   access_key: YOUR_S3_KEY
#   secret: YOUR_S3_SECRET
#   region: us-east-1
#   bucket: letsyak-recordings
#   endpoint: https://s3.example.com
```

---

## 4. Synapse Well-Known Configuration

To enable automatic LiveKit discovery by the client (so users don't need
to manually configure URLs), add the following to your Synapse's
`.well-known/matrix/client` response:

```json
{
  "m.homeserver": {
    "base_url": "https://chat.maybery.app"
  },
  "org.matrix.msc4143.rtc_foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://lk-jwt.maybery.app"
    }
  ]
}
```

If you're running Synapse behind nginx, you can add this to your
`.well-known` location block in your nginx config:

```nginx
location /.well-known/matrix/client {
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '{
      "m.homeserver": {"base_url": "https://chat.maybery.app"},
      "org.matrix.msc4143.rtc_foci": [
        {
          "type": "livekit",
          "livekit_service_url": "https://lk-jwt.maybery.app"
        }
      ]
    }';
}
```

---

## 5. Reverse Proxy (nginx)

Add these to your nginx configuration:

```nginx
# LiveKit WebSocket (for clients)
server {
    listen 443 ssl;
    server_name livekit.maybery.app;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
}

# JWT Service (for token requests)
server {
    listen 443 ssl;
    server_name lk-jwt.maybery.app;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 6. Recording API Proxy (Optional)

The LetsYak client calls a recording API endpoint that proxies requests to
LiveKit Egress. This prevents exposing LiveKit API secrets to the client.

You can implement this as a simple HTTP service. Here's a minimal example
using Node.js:

```javascript
// recording-proxy.js
const express = require('express');
const { EgressClient } = require('livekit-server-sdk');

const app = express();
app.use(express.json());

const egressClient = new EgressClient(
  'ws://livekit:7880',
  'your_api_key',
  'your_api_secret'
);

// Verify Matrix access token before allowing recording
async function verifyToken(req) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) throw new Error('No token');
  // Validate against Synapse
  const resp = await fetch('https://chat.maybery.app/_matrix/federation/v1/openid/userinfo', {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!resp.ok) throw new Error('Invalid token');
  return await resp.json();
}

app.post('/recording/start', async (req, res) => {
  try {
    await verifyToken(req);
    const { room_id } = req.body;
    const output = { filepath: `/tmp/livekit-egress/${room_id}-${Date.now()}.mp4` };
    const info = await egressClient.startRoomCompositeEgress(room_id, { file: output });
    res.json({ egress_id: info.egressId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/recording/stop', async (req, res) => {
  try {
    await verifyToken(req);
    const { egress_id } = req.body;
    await egressClient.stopEgress(egress_id);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(8090, () => console.log('Recording proxy on :8090'));
```

Add this to your Docker Compose:

```yaml
  recording-proxy:
    build: ./recording-proxy
    ports:
      - "8090:8090"
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_KEY=your_api_key
      - LIVEKIT_SECRET=your_api_secret
      - SYNAPSE_URL=https://chat.maybery.app
    restart: unless-stopped
```

---

## 7. DNS Records

Create DNS A/AAAA records pointing to your server:

| Subdomain               | Purpose           |
|--------------------------|-------------------|
| `livekit.maybery.app`   | LiveKit SFU WSS   |
| `lk-jwt.maybery.app`    | JWT token service  |

---

## 8. Firewall Rules

Open these ports:

| Port          | Protocol | Purpose              |
|---------------|----------|----------------------|
| 7880          | TCP      | LiveKit HTTP/WS      |
| 7881          | TCP      | LiveKit RTC (TCP)    |
| 50000-50060   | UDP      | WebRTC media         |
| 8080          | TCP      | JWT service (internal)|
| 443           | TCP      | nginx reverse proxy  |

---

## 9. TURN Server

If you already have Coturn configured for Synapse, LiveKit can reuse it.
Otherwise, LiveKit has a built-in TURN relay.

For the built-in TURN, add to `livekit.yaml`:

```yaml
turn:
  enabled: true
  domain: livekit.maybery.app
  tls_port: 5349
  udp_port: 3478
```

---

## 10. LetsYak Client Configuration

Once services are running, enable calling in the client by updating
`config.json`:

```json
{
  "letsyakCalling": true,
  "letsyakLivekitUrl": "wss://livekit.maybery.app",
  "letsyakJwtServiceUrl": "https://lk-jwt.maybery.app"
}
```

Or, if you configured the `.well-known` discovery (step 4), you can just
set `letsyakCalling: true` and the client will auto-discover the URLs.

---

## 11. Quick Start Checklist

- [ ] Generate LiveKit API key and secret
- [ ] Create `livekit.yaml` with your server's public IP
- [ ] Create `docker-compose.calling.yml`
- [ ] Start services: `docker compose -f docker-compose.calling.yml up -d`
- [ ] Add DNS records for `livekit.maybery.app` and `lk-jwt.maybery.app`
- [ ] Configure nginx reverse proxy with SSL
- [ ] Open firewall ports (7880, 7881, 50000-50060/udp)
- [ ] Update Synapse's `.well-known/matrix/client` with `org.matrix.msc4143.rtc_foci`
- [ ] Update LetsYak `config.json` with `letsyakCalling: true`
- [ ] (Optional) Set up Egress + recording proxy for call recording
- [ ] Test: Open a chat, tap the call button
