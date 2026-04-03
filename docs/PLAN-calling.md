# LetsYak Calling System — Detailed Technical Plan

## Executive Summary

After thorough analysis of the existing FluffyChat calling code, the Matrix VoIP
ecosystem, and available open-source tooling, the recommended path is:

**Use LiveKit SFU with the `livekit_client` Flutter SDK, orchestrated via MatrixRTC
signaling, built as a fully separate module that sits alongside (not replaces) the
existing upstream calling code.**

This gives you: group calls, screen sharing, server-side recording, admin controls,
cross-platform support (mobile + web), upstream merge safety, and a self-hosted
Docker-based backend.

---

## 1. Current State Analysis

### What FluffyChat Has Today

| Feature | Status | Implementation |
|---|---|---|
| 1:1 voice calls | Experimental, off by default | Direct peer-to-peer WebRTC via Matrix SDK VoIP |
| 1:1 video calls | Experimental, off by default | Direct peer-to-peer WebRTC via Matrix SDK VoIP |
| Screen sharing | Implemented (in dialer) | WebRTC screen capture |
| Group calls | NOT implemented | `handleNewGroupCall` is a TODO stub |
| Jitsi Meet | Separate feature, off by default | Opens browser to Jitsi URL via Matrix widget |
| Call recording | NOT implemented | — |
| Admin controls | NOT implemented | — |
| SFU (Selective Forwarding) | NOT implemented | Peer-to-peer only |

### Upstream Files That Touch Calling (Merge Risk Map)

These are the **exact integration seams** between calling code and the rest of the app:

| File | Lines | What It Does | Merge Risk |
|---|---|---|---|
| `lib/widgets/matrix.dart` | Lines 12, 78, 93, 344-352 | Imports `VoipPlugin`, declares field, calls `createVoipPlugin()` | MEDIUM — upstream may change plugin init |
| `lib/config/setting_keys.dart` | Lines 40-42 | `experimentalVoip`, `jitsiFeature`, `jitsiDomain` settings | LOW — rarely changes |
| `lib/pages/chat/chat_view.dart` | Lines 13, 227-236 | Conditional call button in chat header | MEDIUM — chat header changes frequently |
| `lib/pages/chat/chat.dart` | Lines 1364-1410 | `onPhoneButtonTap()` method | LOW — isolated method at end of file |
| `lib/pages/chat/jitsi_popup_button.dart` | Entire file | Jitsi integration widget | LOW — standalone file |
| `lib/utils/voip_plugin.dart` | Entire file | Matrix SDK VoIP bridge | LOW — standalone file |
| `lib/pages/dialer/dialer.dart` | Entire file | Call UI (Calling widget) | LOW — standalone file |
| `lib/pages/dialer/pip/` | Entire directory | PIP view for calls | LOW — standalone directory |
| `lib/utils/voip/` | Entire directory | Video renderer, audio manager | LOW — standalone directory |
| `config.json` / `config.sample.json` | `experimentalVoip` key | Feature flag default | LOW |
| `lib/pages/settings_chat/settings_chat_view.dart` | Lines 87-100 | VoIP toggle in settings | MEDIUM — settings UI changes |

**Key insight**: The existing calling code is well-isolated. Only 4 files in the main
app code reference calling: `matrix.dart`, `chat_view.dart`, `chat.dart`, and
`settings_chat_view.dart`. Everything else is in standalone files/directories.

---

## 2. Three Options Evaluated

### Option A: Enable and Extend FluffyChat's Existing VoIP

**What**: Turn on `experimentalVoip`, implement the TODO stubs for group calls using
the Matrix Dart SDK's built-in `GroupCallSession`.

| Pro | Con |
|---|---|
| Least code to write | Matrix SDK group calls use full-mesh (each participant connects to every other participant) |
| Zero new dependencies | Full-mesh caps out at ~4-6 participants before quality degrades |
| No new server infrastructure | No server-side recording possible (peer-to-peer only) |
| Stays in sync with upstream | No admin controls (muting others, kicking, etc.) |
| | `keyProvider` and `registerListeners` throw `UnimplementedError()` — E2EE for calls broken |
| | `handleNewGroupCall` / `handleGroupCallEnded` are empty TODO stubs |

**Verdict: NOT RECOMMENDED.** Full-mesh WebRTC cannot scale to group calls, has no
recording capability, and no admin controls. Fixing the TODO stubs only gets you
a fragile 4-person max call with no server-side features.

---

### Option B: Embed Element Call as a WebView Widget

**What**: Deploy Element Call as a web app, embed it inside your Flutter app using a
WebView. This is what Element X does on mobile.

| Pro | Con |
|---|---|
| Element Call is production-quality (used by Element X) | WebView embedding has performance/UX compromises |
| Supports group calls, E2EE, raise hand, reactions | Authentication delegation is complex (widget API) |
| Uses LiveKit SFU backend | Not native Flutter — feels like a different app |
| Actively maintained by Element team | Two separate codebases to maintain (EC web app + your Flutter wrapper) |
| Federation support via MatrixRTC | Screen sharing from within a WebView is unreliable on mobile |
| | Recording requires separate LiveKit Egress setup anyway |
| | Admin controls limited to what Element Call exposes |

**Verdict: VIABLE AS FALLBACK.** This is the fastest path to "something works" but the
WebView UX is poor and you lose native control over the calling experience. Good as a
Phase 1 interim while building Option C.

---

### Option C: Native LiveKit Integration via `livekit_client` Flutter SDK (RECOMMENDED)

**What**: Use the `livekit_client` Dart package to build a native calling experience.
Use MatrixRTC signaling (room state events) to coordinate call sessions. Deploy
LiveKit SFU + Egress + lk-jwt-service on your server.

| Pro | Con |
|---|---|
| Full native Flutter UI — you control every pixel | More code to write upfront |
| `livekit_client` supports ALL platforms (Android, iOS, Web, macOS, Windows, Linux) | Need to deploy LiveKit + Egress + JWT service |
| Group calls scale to 100+ participants via SFU | Need to implement MatrixRTC state events yourself |
| Server-side recording via LiveKit Egress (Docker) | New dependency (`livekit_client: ^2.7.0`) |
| Screen sharing works natively across all platforms | |
| Programmatic admin controls: mute/unmute, kick, permissions | |
| E2EE support built into LiveKit SDK | |
| Speaker detection, simulcast, adaptive bitrate built-in | |
| Completely separate from upstream calling code — zero merge conflicts | |
| Docker-based backend fits your existing infrastructure plan | |

**Verdict: RECOMMENDED.** This is the right architecture for your requirements. It
gives you everything you need, stays separate from upstream, and uses the same
technology stack that Element Call uses under the hood.

---

## 3. Recommended Architecture (Option C)

### System Architecture

```
┌─────────────────────────────────────────────────┐
│              LetsYak Flutter App                 │
│                                                  │
│  ┌──────────────────┐  ┌──────────────────────┐ │
│  │ Upstream FluffyChat│  │  LetsYak Calling     │ │
│  │ (untouched)       │  │  Module (NEW)         │ │
│  │                    │  │                       │ │
│  │ • Chat            │  │  • livekit_client SDK │ │
│  │ • Rooms           │──│  • Native call UI     │ │
│  │ • Settings        │  │  • Admin controls     │ │
│  │ • Matrix SDK      │  │  • Screen share       │ │
│  │                    │  │  • Recording trigger  │ │
│  └──────────────────┘  └───────────┬───────────┘ │
└────────────────────────────────────┼─────────────┘
                                     │ WebSocket + WebRTC
                                     ▼
┌─────────────────────────────────────────────────┐
│              Server Infrastructure               │
│                                                  │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │  Synapse      │  │  LiveKit SFU Server      │ │
│  │  Homeserver   │  │  (livekit/livekit Docker) │ │
│  │              │  │  • WebRTC media routing   │ │
│  │  MatrixRTC   │  │  • Simulcast              │ │
│  │  state events │  │  • Speaker detection      │ │
│  └──────┬───────┘  └──────────┬───────────────┘ │
│         │                      │                  │
│  ┌──────┴───────┐  ┌──────────┴───────────────┐ │
│  │ lk-jwt-svc   │  │  LiveKit Egress          │ │
│  │ (MatrixRTC   │  │  (livekit/egress Docker)  │ │
│  │  Auth Service)│  │  • Room composite record │ │
│  │ Issues JWT    │  │  • Track export           │ │
│  │ tokens for    │  │  • Upload to S3/GCS/local│ │
│  │ LiveKit rooms │  │  • RTMP streaming         │ │
│  └──────────────┘  └──────────────────────────┘ │
│                                                  │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │  Redis        │  │  Coturn TURN/STUN        │ │
│  │  (coordination│  │  (NAT traversal)          │ │
│  │   + egress)   │  │                           │ │
│  └──────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Call Flow

```
1. User taps "Call" in a room
2. App creates a MatrixRTC session state event in the room
   (org.matrix.msc3401.call.member)
3. App requests a JWT token from lk-jwt-service
   (POST /livekit/jwt with Matrix access token)
4. lk-jwt-service validates Matrix identity, returns:
   - LiveKit WebSocket URL
   - JWT access token with room + participant identity
5. App connects to LiveKit SFU via livekit_client SDK
6. Other participants see the state event, repeat steps 3-5
7. LiveKit SFU handles media routing, simulcast, speaker detection
8. When call ends, app removes state event from room
```

---

## 4. File Structure (Upstream-Safe)

All new code goes into a `letsyak_calling` directory tree that upstream will never
touch. The only upstream files we modify are the 4 integration seams, and we do so
minimally.

```
lib/
  letsyak/                          ← ALL custom LetsYak code lives here
    calling/                         ← Calling module root
      calling_module.dart            ← Module entry point, feature flag check
      config/
        calling_config.dart          ← LiveKit URL, JWT service URL, feature flags
      models/
        call_session_model.dart      ← Call state: participants, mute states, recording
        call_participant.dart        ← Participant info wrapper
        call_permissions.dart        ← Admin permission model (who can mute/kick/record)
      services/
        livekit_service.dart         ← Wraps livekit_client: connect, disconnect, publish
        matrixrtc_signaling.dart     ← Read/write MatrixRTC state events in room
        jwt_token_service.dart       ← HTTP client to lk-jwt-service
        recording_service.dart       ← Trigger LiveKit Egress start/stop via server API
        call_notification_service.dart ← Incoming call ringtone + push notification
      pages/
        call_screen.dart             ← Main call UI (full screen)
        call_screen_view.dart        ← StatelessWidget view for call screen
        call_lobby.dart              ← Pre-join lobby (camera/mic preview, settings)
        call_controls_bar.dart       ← Bottom bar: mute, camera, share, hang up, record
        participant_grid.dart        ← Grid/speaker layout for video tiles
        participant_tile.dart        ← Single participant video tile
        admin_controls_sheet.dart    ← Bottom sheet: mute participant, kick, etc.
        screen_share_picker.dart     ← Screen/window picker for desktop
        recording_indicator.dart     ← Recording badge/timer
      widgets/
        call_button.dart             ← Reusable call button for chat header
        incoming_call_banner.dart    ← Incoming call notification banner
        call_pip_view.dart           ← Picture-in-picture overlay
        participant_avatar.dart      ← Avatar with indicators (muted, speaking, etc.)
      utils/
        call_audio_manager.dart      ← Speaker/earpiece/bluetooth routing
        call_permissions_helper.dart ← Camera/mic permission requests
        call_ringtone.dart           ← Ringtone playback
```

### Integration Points (Minimal Upstream Changes)

Only **4 files** need modification, each with minimal, clearly-marked changes:

#### 1. `lib/widgets/matrix.dart` — Add calling module initialization

```dart
// LETSYAK: Calling module
import 'package:fluffychat/letsyak/calling/calling_module.dart';

// In MatrixState class:
LetsYakCallingModule? callingModule;  // LETSYAK

// In initState or setActiveClient:
callingModule = LetsYakCallingModule.initialize(client);  // LETSYAK
```

#### 2. `lib/pages/chat/chat_view.dart` — Add call button

```dart
// LETSYAK: Replace or add alongside existing call button
if (LetsYakCallingModule.isEnabled)
  LetsYakCallButton(room: controller.room)
```

#### 3. `lib/config/setting_keys.dart` — Add settings

```dart
// LETSYAK: Calling settings
letsyakCalling<bool>('letsyak.calling.enabled', true),
letsyakLivekitUrl<String>('letsyak.livekit.url', ''),
letsyakJwtServiceUrl<String>('letsyak.jwt_service.url', ''),
```

#### 4. `config.json` — Add configuration

```json
"letsyakCalling": true,
"letsyakLivekitUrl": "wss://livekit.yourdomain.com",
"letsyakJwtServiceUrl": "https://matrix-rtc.yourdomain.com/livekit/jwt"
```

**When merging upstream**: These are additive changes only. They add new lines, not
modify existing ones. The upstream `experimentalVoip` code continues to exist and can
be disabled. Merge conflicts will be trivial (at worst, a new line inserted next to
our added line).

---

## 5. Feature Breakdown

### 5.1 One-to-One Calls

- User taps call button in a direct chat room
- Pre-join lobby shows camera preview + mic level
- Connects to LiveKit room (room name = Matrix room ID)
- Full-screen view with local + remote video
- Controls: mute mic, mute camera, switch camera, speaker toggle, hang up

**Why LiveKit even for 1:1**: Consistent UX across all call types. Plus you get
server-side recording, admin controls, and the ability to "upgrade" a 1:1 call to a
group call by inviting more participants — something impossible with peer-to-peer.

### 5.2 Group Calls

- User taps call button in a group room
- MatrixRTC state event notifies all room members
- Participants join via LiveKit SFU
- Grid layout (2x2, 3x3, etc.) auto-adapts to participant count
- Active speaker highlighted / pinned
- Speaker view mode (one large + small thumbnails)
- Participant list with mute indicators

**Scaling**: LiveKit SFU handles simulcast automatically — each participant publishes
multiple quality layers, and the SFU sends the appropriate layer to each subscriber
based on their bandwidth and the UI layout.

### 5.3 Screen Sharing

Already supported by `livekit_client` across all platforms:

| Platform | How It Works |
|---|---|
| Android | Media projection foreground service |
| iOS | Broadcast extension (ReplayKit) |
| Web | `getDisplayMedia()` browser API |
| macOS/Windows | Desktop capturer with window/screen picker |
| Linux | PipeWire/X11 capture |

Implementation:
```dart
// One line to toggle screen share
await room.localParticipant.setScreenShareEnabled(true);
```

For desktop, show a screen/window picker dialog first.

### 5.4 Call Recording

**Server-side via LiveKit Egress** — no client changes needed for the actual recording.

The client only needs to:
1. Check if the user has permission to record (admin/moderator)
2. Send API request to start/stop recording
3. Show recording indicator to all participants

Recording types available:
- **Room Composite**: Full room recording with layout (like a Zoom recording)
- **Track Composite**: Individual participant's audio+video synced
- **Track**: Raw individual tracks (for post-processing)

Output options:
- MP4/WebM file → upload to S3, GCS, Azure, or local volume
- HLS segments → for live streaming
- RTMP → stream to YouTube Live, Twitch

**Docker deployment** (add to your docker-compose):
```yaml
egress:
  image: livekit/egress:latest
  environment:
    EGRESS_CONFIG_BODY: |
      api_key: your-api-key
      api_secret: your-api-secret
      ws_url: ws://livekit:7880
      redis:
        address: redis:6379
      storage:
        s3:
          bucket: letsyak-recordings
          region: eu-west-1
  depends_on:
    - livekit
    - redis
```

### 5.5 Admin Controls

LiveKit's server API provides full participant management:

| Control | How | API |
|---|---|---|
| Mute a participant | Server-side, cannot be overridden by client | `MutePublishedTrack` |
| Unmute request | Send data message asking participant to unmute | Custom data message |
| Kick participant | Remove from room | `RemoveParticipant` |
| Grant/revoke permissions | Control who can publish audio/video/screen | `UpdateParticipant` |
| Lock room | Prevent new joins | Room metadata update |
| Raise hand | Participant sends data message | Custom data channel |

Permission model:
```
Room Admin (room power level >= 50):
  ✅ Mute any participant
  ✅ Kick any participant
  ✅ Start/stop recording
  ✅ Lock/unlock room
  ✅ Grant screen share permission

Regular Participant:
  ✅ Mute/unmute self
  ✅ Toggle own camera
  ✅ Share screen (if permitted)
  ✅ Raise hand
  ❌ Cannot mute others
  ❌ Cannot kick
  ❌ Cannot record
```

This maps cleanly to Matrix room power levels — whoever is a moderator/admin in the
Matrix room gets admin controls in calls.

### 5.6 Additional Features (via LiveKit SDK)

These come for free with `livekit_client`:

- **Speaker detection**: Visual indicator of who is speaking
- **Simulcast**: Automatic quality adaptation per viewer
- **Adaptive bitrate**: Adjusts to network conditions
- **Noise suppression**: Built-in audio processing
- **End-to-end encryption**: Optional E2EE via LiveKit's implementation
- **Picture-in-Picture**: Already have PIP code from upstream, adapt for LiveKit
- **Background audio**: Audio continues when app is backgrounded
- **Connection quality indicator**: Show each participant's connection strength

---

## 6. Server Infrastructure (Docker Compose)

Complete Docker Compose for the calling backend:

```yaml
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"   # HTTP/WebSocket
      - "7881:7881"   # RTC (TCP)
      - "50000-50200:50000-50200/udp"  # RTC (UDP range)
    environment:
      LIVEKIT_KEYS: "your-api-key: your-api-secret"
    volumes:
      - ./livekit-config.yaml:/etc/livekit.yaml
    command: --config /etc/livekit.yaml

  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    environment:
      LIVEKIT_URL: ws://livekit:7880
      LIVEKIT_KEY: your-api-key
      LIVEKIT_SECRET: your-api-secret
      # Synapse homeserver for Matrix identity verification
      MATRIX_HOMESERVER: https://chat.maybery.app
    ports:
      - "8080:8080"

  egress:
    image: livekit/egress:latest
    environment:
      EGRESS_CONFIG_BODY: |
        api_key: your-api-key
        api_secret: your-api-secret
        ws_url: ws://livekit:7880
        redis:
          address: redis:6379
    depends_on:
      - livekit
      - redis
    # Mount volume for local recording storage
    volumes:
      - ./recordings:/out

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  coturn:
    image: coturn/coturn:latest
    ports:
      - "3478:3478"
      - "3478:3478/udp"
      - "49152-49200:49152-49200/udp"
    environment:
      TURN_REALM: turn.yourdomain.com
      TURN_USER: livekit
      TURN_PASSWORD: turn-secret
```

### Synapse `.well-known` Configuration

Add to your homeserver's `/.well-known/matrix/client`:
```json
{
  "m.homeserver": {
    "base_url": "https://chat.maybery.app"
  },
  "org.matrix.msc4143.rtc_foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://matrix-rtc.maybery.app/livekit/jwt"
    }
  ]
}
```

This is the MatrixRTC discovery mechanism (MSC4143). Clients discover the LiveKit
backend from the homeserver's well-known file.

---

## 7. Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  livekit_client: ^2.7.0   # LiveKit Flutter SDK (all platforms)
  # flutter_webrtc already in project — livekit_client uses it internally
  # No other new dependencies needed
```

`livekit_client` is the only new dependency. It internally uses `flutter_webrtc`
(which the project already depends on) and handles all platform-specific WebRTC
complexity.

---

## 8. Implementation Phases

### Phase A: Infrastructure Setup (1 week)

1. Deploy LiveKit SFU server (Docker)
2. Deploy lk-jwt-service (Docker)
3. Deploy Redis (Docker)
4. Configure Synapse `.well-known` with `org.matrix.msc4143.rtc_foci`
5. Deploy Coturn for NAT traversal
6. Test with LiveKit's example app to verify infrastructure works
7. Generate API keys and configure all services

### Phase B: Core Calling Module (2-3 weeks)

1. Create `lib/letsyak/calling/` directory structure
2. Implement `LiveKitService` — connect, disconnect, publish tracks
3. Implement `JwtTokenService` — fetch JWT from lk-jwt-service
4. Implement `MatrixRtcSignaling` — read/write call state events
5. Build `CallScreen` — basic call UI with video tiles
6. Build `CallControlsBar` — mute, camera, hang up
7. Wire into `matrix.dart` and `chat_view.dart` (minimal changes)
8. Test 1:1 calls on web and mobile

### Phase C: Group Calls + UI Polish (2 weeks)

1. Build `ParticipantGrid` — adaptive grid layout
2. Build `ParticipantTile` — video tile with name, mute indicator, speaking indicator
3. Implement speaker detection UI (highlight active speaker)
4. Build `CallLobby` — pre-join screen with camera/mic preview
5. Test group calls with 3+ participants across mobile and web
6. Implement PIP view for background calling

### Phase D: Screen Sharing (1 week)

1. Implement screen share toggle in controls bar
2. Build `ScreenSharePicker` for desktop platforms
3. Configure Android foreground service for screen capture
4. Configure iOS broadcast extension
5. Test screen sharing on all platforms

### Phase E: Recording (1 week)

1. Deploy LiveKit Egress (Docker)
2. Implement `RecordingService` — start/stop recording via server API
3. Build `RecordingIndicator` widget
4. Add recording button to admin controls
5. Configure storage (S3 or local volume)
6. Test recording end-to-end

### Phase F: Admin Controls (1 week)

1. Implement permission model based on Matrix room power levels
2. Build `AdminControlsSheet` — mute participant, kick, permissions
3. Implement server-side mute via LiveKit API
4. Implement raise hand via LiveKit data channel
5. Add participant list with admin actions
6. Test admin controls across different user roles

### Phase G: Polish + Edge Cases (ongoing)

1. Incoming call notifications (push notifications for calls)
2. Call history / missed calls (store in Matrix room events)
3. Bluetooth audio routing
4. Network quality indicator
5. Reconnection handling (auto-rejoin on network change)
6. Accessibility (screen reader support for call UI)

---

## 9. Risk Mitigation

| Risk | Mitigation |
|---|---|
| Upstream merge conflicts | ALL new code in `lib/letsyak/` — only 4 lines in upstream files, all additive |
| `livekit_client` version conflicts with `flutter_webrtc` | Both are maintained by the same team; pin compatible versions |
| LiveKit SFU server goes down | Health checks + auto-restart in Docker; graceful degradation to "call unavailable" |
| Browser screen sharing permissions | Use proper `getDisplayMedia` API; show user-friendly permission dialogs |
| iOS broadcast extension setup | Follow LiveKit's documented setup; test on real devices early |
| JWT token expiry during long calls | Implement token refresh in `JwtTokenService`; LiveKit handles reconnection |
| Recording storage costs | Configure auto-cleanup policy; offer recording as premium feature |
| MatrixRTC spec still evolving (MSC3401/4143/4195) | Follow Element Call's implementation as reference; their MSC implementations are de facto standard |

---

## 10. Why Not Just Enable `experimentalVoip`?

To be explicit about why simply turning on the existing feature flag is insufficient:

1. **Group calls don't work** — `handleNewGroupCall` and `handleGroupCallEnded` are
   empty TODO stubs that do nothing
2. **Full-mesh doesn't scale** — Even if you implemented the TODOs, peer-to-peer
   WebRTC connects every participant to every other participant. At 5 people that's 20
   connections. At 10 people that's 90. Quality degrades rapidly past 4 participants.
3. **No recording possible** — Peer-to-peer streams never touch a server, so there's
   nothing to record server-side. Client-side recording is unreliable and
   platform-limited.
4. **No admin controls** — Peer-to-peer has no central authority to enforce mutes or
   kicks. Each client controls its own media.
5. **E2EE is broken** — `keyProvider` throws `UnimplementedError()`
6. **`registerListeners` throws** — Essential lifecycle callback is not implemented
7. **Jitsi is a dead end** — Opens a browser window, no native integration, no
   recording, no admin controls, separate authentication stack

The existing code is fine for what it was designed for (experimental 1:1 calls between
two FluffyChat users). It is not a foundation to build production calling features on.

---

## 11. Relationship to Upstream

### Strategy: Additive, Not Replacing

- **Keep** the existing `experimentalVoip` code untouched — it continues to work if
  someone enables it
- **Keep** the Jitsi code untouched — it's in its own file and doesn't interfere
- **Add** our own calling module in a completely separate directory
- **Add** a new feature flag (`letsyakCalling`) that takes precedence over the old ones
- When `letsyakCalling` is enabled, the chat header shows our call button instead of
  the upstream one

### Merge Strategy

When pulling upstream changes:
1. `git merge upstream/main` — should auto-merge 95% of the time
2. If `chat_view.dart` conflicts (our added call button near upstream's changes),
   resolve by keeping both and ensuring our conditional is intact
3. If `matrix.dart` conflicts (our added module init near upstream's init code),
   resolve by keeping our additive line
4. Run tests after every merge
5. The `lib/letsyak/` directory will NEVER conflict because upstream doesn't have it

---

## 12. Testing Strategy

| Level | What | How |
|---|---|---|
| Unit | LiveKitService, JwtTokenService, MatrixRtcSignaling | Dart unit tests with mocked dependencies |
| Widget | CallScreen, ParticipantGrid, AdminControls | Flutter widget tests |
| Integration | Full call flow (create → join → media → leave) | Integration tests against local LiveKit server |
| Cross-platform | Web + Android + iOS | Manual testing on each platform; CI for web |
| Load | Group calls with 10+ participants | LiveKit CLI load test tool (`lk room join --publish-demo`) |

---

## Summary Decision Matrix

| Requirement | Option A (Enable existing) | Option B (Element Call WebView) | **Option C (Native LiveKit)** |
|---|---|---|---|
| 1:1 calls | ✅ | ✅ | **✅** |
| Group calls | ❌ (4 person max) | ✅ | **✅** |
| Screen sharing | ✅ | ⚠️ (WebView issues on mobile) | **✅** |
| Recording | ❌ | ✅ (needs Egress separately) | **✅** |
| Admin controls | ❌ | ⚠️ (limited to EC's UI) | **✅** |
| Mobile + Web | ✅ | ⚠️ (WebView UX) | **✅** |
| Upstream merge safety | ✅ | ✅ | **✅** |
| Native Flutter UI | ✅ | ❌ | **✅** |
| Custom UX control | ✅ | ❌ | **✅** |
| Time to first call | 1 day | 1-2 weeks | **2-3 weeks** |
| Production readiness | ❌ | ⚠️ | **✅** |

**Recommendation: Option C — Native LiveKit integration via `livekit_client`.**

The additional 2-3 weeks of initial development pays for itself immediately in
feature completeness, production quality, and zero upstream merge risk. You build it
once and own the entire calling experience.
