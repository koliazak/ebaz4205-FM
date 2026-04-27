import json
import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
import jwt

from core.state import active_clients, active_devices, device_metadata
from core.security import (
    verify_jwt_token,
    verify_device_auth,
    create_device_jwt,
    require_device
)


logger = logging.getLogger(__name__)

router = APIRouter()

class DeviceAuthRequest(BaseModel):
    device_id: str
    timestamp: int
    nonce: str
    signature: str

@router.post("/api/device/login")
async def login_device(req: DeviceAuthRequest):
    is_valid = await verify_device_auth(
        device_id=req.device_id,
        timestamp=req.timestamp,
        nonce=req.nonce,
        signature=req.signature
    )

    if not is_valid:
        raise HTTPException(status_code=401, detail="Unauthorized: Invalid signature or expired request")

    token = create_device_jwt(device_id=req.device_id, scope=["audio:stream", "cmd:receive"])
    return {"access_token": token}

@router.websocket("/device/ws")
async def device_websocket(websocket: WebSocket):

    auth_header = websocket.headers.get("authorization")

    if not auth_header or not auth_header.startswith("Bearer "):
        logger.warning("WS Handshake Failed: Missing or invalid Authorization header")
        await websocket.close(code=1008)
        return

    token = auth_header.split(" ")[1]

    try:
        payload = verify_jwt_token(token)
        device_id = await require_device(payload=payload, required_scope="audio:stream")
    except jwt.InvalidTokenError as ex:
        logger.warning(f"WS Auth Failed: {ex}")
        await websocket.close(1008)
        return

    await websocket.accept()
    active_devices[payload["sub"].split(":", 1)[1]] = websocket
    logger.info(f"Device {device_id} connected securely!")

    try:
        while True:
            message = await websocket.receive()

            if "bytes" in message and message["bytes"]:

                dead_clients = []
                for client_ws in active_clients:
                    try:
                        await client_ws.send_bytes(message["bytes"])
                    except Exception as ex:
                        logger.warning(ex)
                        dead_clients.append(client_ws)

                for dead in dead_clients:
                    if dead in active_clients:
                        active_clients.remove(dead)

            elif "text" in message and message["text"]:
                try:
                    data = json.loads(message["text"])

                    if data.get("type") == "state_update":
                        try:
                            device_metadata[device_id].update(data)
                        except KeyError:
                            device_metadata[device_id] = data
                    dead_clients = []
                    for client_ws in active_clients:
                        try:
                            await client_ws.send_text(message["text"])
                        except Exception as ex:
                            logger.warning(ex)
                            dead_clients.append(client_ws)

                    for dead in dead_clients:
                        if dead in active_clients:
                            active_clients.remove(dead)
                except json.JSONDecodeError:
                    logger.error(f"Received invalid JSON from board {device_id}")

    except WebSocketDisconnect as ex:
        logger.info(f"Device {device_id} disconnected")
    except Exception as e:
        logger.error(f"Unexpected error with device '{device_id}': {e}", exc_info=True)

