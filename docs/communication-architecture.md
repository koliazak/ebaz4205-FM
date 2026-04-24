# Device - Relay Security Architecture (JWT)

## Overview

This architecture secures communication between a Zynq-7010 (PetaLinux) device and a public Relay Server (AWS EC2).

The device uses:

- WebSocket channel for audio transpher
- WebSocket channel for command accept

Security is based on:

- `wss://`, `https://` for encrypted transport
- JWT access tokens for auth

---

## Components

- **Device Agent**
  - Stores credentials/tokens securely
  - Handles token refresh and WebSocket reconnect

- **Auth**
  - Issues/refreshes tokens

- **Relay**
  - Validates JWT on WebSocket connection
  - Enforces permissions
  - Routes audio and command traffic

---

## Identity and Bootstrap

Each device has:

- `device_id` (stable unique identifier)
- provisioned `secret`

---

## Runtime Flows

1. **Bootstrap**
   - Device calls `POST /device/auth` with `HMAC(secret, device_id:timestamp:nonce)`
   - Receives `access_token`, `expires_in`

2. **Normal operation**
   - Device connects to `wss://relay/...` using access token
   - Relay validates JWT and scope
   - Audio/commands flow through dedicated WebSocket channels

3. **Refresh**
   - Device refreshes before access token expiry (`POST /device/auth (HMAC)`)
   - Receives new token

4. **Recovery**
   - If refresh fails irrecoverably, device performs bootstrap again

---

## Relay Validation Rules

Relay must validate:

- JWT signature
- `iss` and `aud`
- `exp` with small clock-skew tolerance
- `device_id` is active
- required `scope` for the channel/action
