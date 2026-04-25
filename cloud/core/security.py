import jwt
import hmac
import time
import hashlib
from datetime import datetime, timedelta, UTC

SECRET_KEY = "SECRET_KEY"
HMAC_SECRETS = {
    "zynq_01": b"device_secret_123",
}

ALGORITHM = "HS256"
CLOCK_SKEW_TOLERANCE = 10

EXPECTED_ISSUER = "urn:techforge:auth"
EXPECTED_AUDIENCE = "urn:techforge:relay"

ACCESS_TOKEN_LIFETIME = 900 # 15 min

ACTIVE_DEVICES = {
    "zynq_01": {"is_active": True},
}

USED_NONCES = {}
NONCE_TTL = 60 # sec


def _cleanup_nonces():
    now = time.time()
    for n in list(USED_NONCES):
        if now - USED_NONCES[n] > NONCE_TTL:
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
def verify_device_auth(device_id: str, timestamp: int, nonce: str, signature: str) -> bool:
    if device_id not in HMAC_SECRETS:
        return False

    now = int(time.time())
    if abs(now - timestamp) > 60:
        return False

    message = f"{device_id}:{timestamp}:{nonce}"
    expected = generate_hmac(HMAC_SECRETS[device_id], message)

    return hmac.compare_digest(expected, signature)


# JWT

def create_device_jwt(device_id: str, scope: list[str]) -> str:
    expire = datetime.now(UTC) + timedelta(seconds=ACCESS_TOKEN_LIFETIME)

    payload = {
        "sub": f"device:{device_id}",
        "type": "device",
        "scope": scope,
        "iss": EXPECTED_ISSUER,
        "aud": EXPECTED_AUDIENCE,
        "iat": datetime.now(UTC),
        "exp": expire
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def create_user_jwt(user_id: str, scope: list[str]) -> str:
    expire = datetime.now(UTC) + timedelta(seconds=ACCESS_TOKEN_LIFETIME)

    payload = {
        "sub": f"user:{user_id}",
        "type": "user",
        "scope": scope,
        "iss": EXPECTED_ISSUER,
        "aud": EXPECTED_AUDIENCE,
        "iat": datetime.now(UTC),
        "exp": expire
    }

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_jwt_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        SECRET_KEY,
        algorithms=[ALGORITHM],
        issuer=EXPECTED_ISSUER,
        audience=EXPECTED_AUDIENCE,
        leeway=CLOCK_SKEW_TOLERANCE
    )
    return payload


def require_device(payload: dict, required_scope: str) -> str:
    if payload.get("type") != "device":
        raise jwt.InvalidTokenError("Not a device token")

    sub = payload.get("sub")
    if not sub or not sub.startswith("device:"):
        raise jwt.InvalidTokenError("Invalid subject")

    device_id = sub.split(":", 1)[1]
    device_record = ACTIVE_DEVICES.get(device_id)
    if not device_record or not device_record.get("is_active"):
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
