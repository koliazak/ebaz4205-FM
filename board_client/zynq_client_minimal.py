import logging
import time
import hmac
import hashlib
import uuid
import asyncio
import websockets
import json
import urllib.request
import base64

import hw_control


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
LOGIN_URL = "https://techforge.best/api/device/login"
WS_URL = "wss://techforge.best/device/ws"

radio_hw = hw_control.FPGARadioController()

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
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(LOGIN_URL, data=data, headers={'Content-Type': 'application/json'})

        with urllib.request.urlopen(req, timeout=5) as response:
            if response.getcode() == 200:
                logger.info("HMAC Auth Success! Got JWT.")
                response_data = json.loads(response.read().decode('utf-8'))
                return response_data["access_token"]
            else:
                logger.error(f"Auth Failed: {response.getcode()}")
                return None
    except Exception as e:
        logger.error(f"Network error: {e}", exc_info=True)
        return None

async def audio_sender(ws):
    try:
        process = await asyncio.create_subprocess_exec(
            "./audio_rx",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        logger.info("Audio source is connected.")
    except Exception as ex:
        logger.error(f"Error in Audio Sender {ex}", exc_info=True)
        return

    try:
        while True:
            data = await process.stdout.read(1024)

            if not data:
                break

            await ws.send(data)
    except asyncio.CancelledError:
        logger.info("Audio Sender Task stopped.")
    except Exception as ex:
        logger.error(f"Error in Audio Sender: {ex}")

async def command_receiver(ws):
    logger.info("Command Receiver Task started.")

    try:
        async for message in ws:
            if isinstance(message, bytes):
                continue

            try:
                payload: dict = json.loads(message)
                cmd = payload.get("cmd")
                value = payload.get("value")
                logger.info(f"Received command: {cmd} (value: {value})")

                match cmd:
                    case "set_freq":
                        logger.info(f"Setting frequency to {value}MHz")
                        await asyncio.to_thread(radio_hw.set_freq, value)
                        
                        current_freq = radio_hw.get_freq()
                        await ws.send(json.dumps({"type": "state_update", "freq": current_freq}))
                    case "scan_up":
                        logger.info(f"Start searching up...")
                        await asyncio.to_thread(radio_hw.search_up)
                        
                        current_freq = radio_hw.get_freq()
                        await ws.send(json.dumps({"type": "state_update", "freq": current_freq}))
                    case "scan_down":
                        logger.info(f"Start searching down...")
                        await asyncio.to_thread(radio_hw.search_down)
                        
                        current_freq = radio_hw.get_freq()
                        ws.send(json.dumps({"type": "state_update", "freq": current_freq}))
                    case _:
                        logger.warning(f"Unknown command <{cmd}>")

            except json.JSONDecodeError:
                logger.error(f"Received invalid JSON: {message}")

    except asyncio.CancelledError:
        logger.info("Command Receiver Task stopped.")

    except Exception as ex:
        logger.error(f"Error in Command Receiver: {ex}", exc_info=True)

async def interrupt_listener(ws):
    logger.info("Interrupt Listener Task started.")
    try:
        while True:
            irq = await asyncio.to_thread(radio_hw.wait_irq)

            if irq:
                logger.info("Interrupt received. Search operation is done.")
                current_freq = await asyncio.to_thread(radio_hw.get_freq)
                payload = {"type": "state_update", "freq": current_freq}
                await ws.send(json.dumps(payload))

    except asyncio.CancelledError:
        logger.info("Interrupt Listener Task stopped.")
    except Exception as ex:
        logger.error(f"Error in Command Receiver: {ex}", exc_info=True)

async def main():
    while True:
        token = get_jwt()

        if not token:
            logger.info("Retrying in 5 seconds...")
            await asyncio.sleep(5)
            continue

        payload_b64 = token.split('.')[1]
        payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
        payload_json = base64.urlsafe_b64decode(payload_b64).decode('utf-8')

        exp = json.loads(payload_json)["exp"]

        try:
            async with websockets.connect(WS_URL, additional_headers={"Authorization": f"Bearer {token}"}) as ws:
                current_freq = await asyncio.to_thread(radio_hw.get_freq)
                await ws.send(json.dumps({"type": "state_update", "freq": current_freq}))
                logger.info("WebSocket Connected!")

                sender_task = asyncio.create_task(audio_sender(ws))
                receiver_task = asyncio.create_task(command_receiver(ws))
                irq_task = asyncio.create_task(interrupt_listener(ws))

                while True:
                    timestamp = int(time.time())
                    if abs(exp - timestamp) < 5:
                        logger.info("Token is about to expire. Initiating reconnect.")
                        break

                    if sender_task.done() or receiver_task.done() or irq_task.done():
                        logger.warning("One of the background tasks finished. Restarting...")
                        break

                    await asyncio.sleep(1)

                sender_task.cancel()
                receiver_task.cancel()
                irq_task.cancel()

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
