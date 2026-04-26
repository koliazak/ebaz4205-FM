import jwt
import hmac
import time
import hashlib
from datetime import datetime, timedelta, UTC

from cryptography.hazmat.primitives.ciphers import aead

from core.config import config
from core.database import find_device


USED_NONCES = {}


def _cleanup_nonces():
    now = time.time()
    for n in list(USED_NONCES):
        if now - USED_NONCES[n] > int(config.NONCE_TTL):
            del USED_NONCES[n]

def verify_nonce(nonce: str) -> bool:
    _cleanup_nonces()

    if nonce in USED_NONCES:
        return False

    USED_NONCES[nonce] = time.time()
    return True

def generate_hmac(secret: bytes, message: str) -> str:
    return hmac.new(secret, message.encode(), hashlib.sha256).hexdigest()

# HMAC auth
async def verify_device_auth(device_id: str, timestamp: int, nonce: str, signature: str) -> bool:
    db_device = await find_device(device_id)
    if not db_device:
        return False

    now = int(time.time())
    if abs(now - timestamp) > 60:
        return False

    message = f"{device_id}:{timestamp}:{nonce}"
    expected = generate_hmac(db_device["device_secret"].encode("utf-8"), message)

    return hmac.compare_digest(expected, signature)


# JWT

def create_device_jwt(device_id: str, scope: list[str]) -> str:
    expire = datetime.now(UTC) + timedelta(seconds=config.ACCESS_TOKEN_LIFETIME)

    payload = {
        "sub": f"device:{device_id}",
        "type": "device",
        "scope": scope,
        "iss": config.EXPECTED_ISSUER,
        "aud": config.EXPECTED_AUDIENCE,
        "iat": datetime.now(UTC),
        "exp": expire
    }

    return jwt.encode(payload, config.JWT_SECRET, algorithm=config.ALGORITHM)

def create_user_jwt(user_id: str, scope: list[str]) -> str:
    expire = datetime.now(UTC) + timedelta(seconds=config.ACCESS_TOKEN_LIFETIME)

    payload = {
        "sub": f"user:{user_id}",
        "type": "user",
        "scope": scope,
        "iss": config.EXPECTED_ISSUER,
        "aud": config.EXPECTED_AUDIENCE,
        "iat": datetime.now(UTC),
        "exp": expire
    }

    return jwt.encode(payload, config.JWT_SECRET, algorithm=config.ALGORITHM)


def verify_jwt_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        config.JWT_SECRET,
        algorithms=[config.ALGORITHM],
        issuer=config.EXPECTED_ISSUER,
        audience=config.EXPECTED_AUDIENCE,
        leeway=config.CLOCK_SKEW_TOLERANCE
    )
    return payload


async def require_device(payload: dict, required_scope: str) -> str:
    if payload.get("type") != "device":
        raise jwt.InvalidTokenError("Not a device token")

    sub = payload.get("sub")
    if not sub or not sub.startswith("device:"):
        raise jwt.InvalidTokenError("Invalid subject")

    device_id = sub.split(":", 1)[1]
    device_record = await find_device(device_id)
    print("device_record.get('is_active')", device_record["is_active"])
    if not device_record or not device_record["is_active"]:
        raise jwt.InvalidTokenError("Device inactive")

    scopes = payload.get("scope", [])
    if required_scope not in scopes:
        raise jwt.InvalidTokenError("Missing scope")

    return device_id


def require_user(payload: dict, required_scope: str) -> str:
    if payload.get("type") != "user":
        raise jwt.InvalidTokenError("Not a user token")

    sub = payload.get("sub")
    if not sub or not sub.startswith("user:"):
        raise jwt.InvalidTokenError("Invalid subject")

    user_id = sub.split(":", 1)[1]

    scopes = payload.get("scope", [])
    if required_scope not in scopes:
        raise jwt.InvalidTokenError("Missing scope")

    return user_id
