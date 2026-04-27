import uuid
import logging
import aiosqlite
import jwt
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status, HTTPException
from bcrypt import hashpw, checkpw, gensalt
from pydantic import BaseModel

from core.state import active_clients, active_devices
from core.security import verify_jwt_token, require_user, create_user_jwt
from core.database import add_user, find_user

salt: bytes = gensalt()

class UserAuthRequest(BaseModel):
    username: str
    password: str

logger = logging.getLogger(__name__)

router = APIRouter()

USERS_DB = {}

@router.post("/api/auth/register", status_code=status.HTTP_201_CREATED)
async def register_user(user: UserAuthRequest):

    hashed_password = hashpw(user.password.encode("utf-8"), salt)
    try:
        await add_user(username=user.username, hashed_password=hashed_password)
    except aiosqlite.IntegrityError:
        raise HTTPException(status_code=400, detail="Username already exists")

    return {"message": "User registered successfully"}

@router.post("/api/auth/guest")
async def get_guest_token():
    guest_id = f"guest_{uuid.uuid4().hex[:8]}"

    token = create_user_jwt(user_id=guest_id, scope=["audio:listen"])
    return {"access_token": token, "role": "guest"}

@router.post("/api/auth/login")
async def login_user(user: UserAuthRequest):
    db_user = await find_user(user.username)

    if not db_user:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    if not checkpw(user.password.encode("utf-8"), db_user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    token = create_user_jwt(user_id=user.username, scope=["audio:listen", "cmd:send"])
    return {"access_token": token, "role": "registered"}


@router.websocket("/client/ws")
async def client_websocket(websocket: WebSocket, token: str):
    try:
        payload = verify_jwt_token(token)
        user_id = require_user(payload, required_scope="audio:listen")
    except jwt.InvalidTokenError as ex:
        logger.warning(f"Client WS Auth Failed: {ex}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    active_clients.add(websocket)
    logger.info(f"User {user_id} joined the stream.")


    try:
        while True:
            command_data = await websocket.receive_json()

            try:
                require_user(payload, required_scope="cmd:send")
            except jwt.InvalidTokenError:
                await websocket.send_json({"error": "No permission to send commands"})
                continue

            target_device = command_data.get("target")
            cmd = command_data.get("cmd")
            value = command_data.get("value")
            if target_device in active_devices:
                device_ws = active_devices[target_device]
                await device_ws.send_json({"cmd": cmd, "value": value})
                logger.info(f"User '{user_id}' sent '{cmd}' (value: {value}) to '{target_device}'")
            else:
                await websocket.send_json({"error": f"Device {target_device} is offline"})

    except WebSocketDisconnect:
        if websocket in active_clients:
            active_clients.remove(websocket)
        logger.info(f"User {user_id} left the stream.")

    except Exception as e:
        active_clients.discard(websocket)
        logger.error(f"Error handling client {user_id}: {e}", exc_info=True)