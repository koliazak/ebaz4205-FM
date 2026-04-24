# Secure Communication Architecture for Electronic Device and Relay Server

## 1. Overview

This document describes a secure communication architecture between:

- Device (Zynq-7010 based board)
- Relay Server (AWS EC2 endpoint)

The device maintains one WebSocket channel to the relay server:

1. Audio stream WebSocket** (device -> relay): streams audio data
2. Command WebSocket (relay -> device): delivers control commands

The core transport security model is **mutual TLS (mTLS)**.  
The device also supports certificate lifecycle operations (bootstrap + rotation) and application-level authorization (JWT).

---

## 2. Security Goals

- Authenticate both server and device (bidirectional trust)
- Encrypt all traffic in transit
- Allow secure certificate renewal before expiration
- Recover from expired or missing certificates via bootstrap flow
- Protect command and streaming channels against unauthorized access
- Keep device identity stable and auditable

---

## 3. High-Level Architecture

### 3.1 Components

- **Device Agent**
  - Holds device private key and client certificate
  - Opens WebSocket connections over TLS
  - Performs certificate renewal
  - Falls back to bootstrap endpoint if needed

- **Relay Server**
  - Terminates TLS/mTLS
  - Verifies device certificate chain and revocation status (if enabled)
  - Authorizes WebSocket sessions (JWT claims, certificate identity mapping)
  - Routes audio and commands

- **Certificate/Enrollment Service** (can be part of relay backend)
  - Issues and renews client certificates
  - Exposes:
    - **Renewal endpoint** (mTLS-protected)
    - **Bootstrap endpoint** (Bearer-based initial enrollment / recovery)

- **Certificate Authority (CA)**
  - Dedicated CA for device certificates (recommended)
  - Optional intermediate CA for separation of duties

---

## 4. Communication Flows



## 4.1 Device Runtime Flow (mTLS only)

1. Device opens TLS connection to relay endpoint.
2. Relay presents server certificate; device validates chain + hostname.
3. Relay requests client certificate.
4. Device presents client cert; relay validates it.
5. WebSocket upgrade occurs over established mTLS channel.

As a result: secure bidirectional channel with strong device authentication.

---  

## 4.2 Browser/Client Runtime Flow (JWT Only)

1. User authenticates via standard HTTPS POST to the relay server.
2. Server validates credentials and returns a signed JWT.
3. Browser opens a secure WebSocket (WSS) connection to the client endpoint.
4. Browser passes the JWT.
5. Server validates the JWT signature and claims before allowing access to the audio stream and control channels.

---  

## 4.3 Certificate Renewal Flow (Periodic, every N days)

1. Device initiates renewal before certificate expiration (at 80% lifetime or fixed interval).
2. Device calls renewal endpoint using current valid mTLS credentials.
3. Device submits CSR generated from on-device private key.
4. Enrollment service validates device policy and issues new short-lived client cert.
5. Device atomically stores new cert, keeps private key secure.
6. Device reloads connection using updated cert.

---  

## 4.4 Bootstrap / Recovery Flow

Used for first cerificate or expired certificate recovery.

1. Device calls bootstrap endpoint over https.
2. Device sends Bearer token derived from:
   - eth0 MAC address
   - embedded secret
3. Server validates token.
4. Device submits CSR and receives initial/recovery cert.
5. Device switches to mTLS-only operational mode.

---  

## 5. Endpoint Set

**Device Endpoints (Hardware ➔ Relay):**
- `wss://relay/device/ws` (mTLS Only) - Full-duplex channel for sending audio and recieving commands.
- `POST https://relay/api/cert/renew` (mTLS, CSR in body)
- `POST https://relay/api/cert/bootstrap` (Standard TLS + Bearer token, CSR in body)

**Client Endpoints (Browser ➔ Relay):**
- `POST https://relay/api/auth/login` (Standard TLS, returns JWT)
- `wss://relay/client/ws` (JWT Auth) - Full-duplex channel for audio and commands.

---  

## 6. Implementation Checklist

- [ ] CSR-based issuance implemented
- [ ] Renewal scheduler
- [ ] Bootstrap token uses HMAC
- [ ] mTLS used on WebSocket endpoints
- [ ] JWT validation for client
- [ ] Monitoring/alerting for renewal and auth failures configured
