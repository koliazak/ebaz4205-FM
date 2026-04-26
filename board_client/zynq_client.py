import logging
import time
import hmac
import hashlib
import uuid

import jwt
import requests
import asyncio
import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - [%(name)s] - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


DEVICE_ID = "zynq_81480f26"
DEVICE_SECRET = b"53b335ce1e58bec9329dfc6878b3253e04044b21d39e69b026cbbdd66f989331"
LOGIN_URL = "http://127.0.0.1:8000/api/device/login"
WS_URL = "ws://127.0.0.1:8000/device/ws"


def generate_hmac(secret: bytes, message: str) -> str:
    return hmac.new(secret, message.encode(), hashlib.sha256).hexdigest()


def get_jwt():
    timestamp = int(time.time())
    nonce = uuid.uuid4().hex
    message = f"{DEVICE_ID}:{timestamp}:{nonce}"
    signature = generate_hmac(DEVICE_SECRET, message)
    payload = {
        "device_id": DEVICE_ID,
        "timestamp": timestamp,
        "nonce": nonce,
        "signature": signature
    }

    try:
        response = requests.post(LOGIN_URL, json=payload, timeout=5)
        if response.status_code == 200:
            logger.info("HMAC Auth Success! Got JWT.")
            return response.json()["access_token"]
        else:
            logger.error(f"Auth Failed: {response.status_code} - {response.text}", exc_info=True)
            return None
    except Exception as e:
        logger.error(f"Network error: {e}", exc_info=True)
        return None


async def main():
    process = await asyncio.create_subprocess_exec(
        "./audio_rx",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.DEVNULL
    )
    logger.info("Audio source is connected.")


    while True:
        token = get_jwt()

        if not token:
            logger.info("Retrying in 5 seconds...")
            await asyncio.sleep(5)
            continue

        exp = jwt.decode(token, options={"verify_signature": False})["exp"]

        try:
            async with websockets.connect(WS_URL,
                                          additional_headers={"Authorization": f"Bearer {token}"}) as ws:
                logger.info("WebSocket Connected!")

                while True:
                    timestamp = int(time.time())
                    if abs(exp - timestamp) < 5:
                        break
                    # data = 1024*b'd5'
                    data = await process.stdout.read(1024)
                    if not data:
                        break
                    await ws.send(data)

        except websockets.exceptions.ConnectionClosedError as e:
            if e.code == 1008:
                logger.info("JWT Expired! Will generate a new one.")
            else:
                logger.warning(f"Disconnected: {e}", exc_info=True)
        except Exception as e:
            logger.error(f"Error: {e}")
            await asyncio.sleep(5)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Service stopped.")
        pass