import time
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
import jwt


from core.security import (
    verify_jwt_token,
    verify_device_auth,
    create_device_jwt,
    require_device
)

router = APIRouter()

class DeviceAuthRequest(BaseModel):
    device_id: str
    timestamp: int
    nonce: str
    signature: str

@router.post("/api/device/login")
async def login_device(req: DeviceAuthRequest):
    is_valid = verify_device_auth(
        device_id=req.device_id,
        timestamp=req.timestamp,
        nonce=req.nonce,
        signature=req.signature
    )

    if not is_valid:
        raise HTTPException(status_code=401, detail="Unauthorized: Invalid signature or expired request")

    scopes = ["audio:stream", "cmd:receive"]
    token = create_device_jwt(device_id=req.device_id, scope=scopes)
    return {"access_token": token}

@router.websocket("devive/ws")
async def device_websocket(websocket: WebSocket, token: str):
    try:
        payload = verify_jwt_token(token)
        device_id = require_device(payload=payload, required_scope="audio:stream")
    except jwt.InvalidTokenError as ex:
        print(f"WS Auth Failed: {ex}")
        await websocket.close(1008)
        return

    await websocket.accept()
    print(f"Device {device_id} connected securely!")

    try:
        while True:
            data = await websocket.receive_bytes()
            # TODO retranslate
    except WebSocketDisconnect as ex:
        print(f"Device {device_id} disconnected")
