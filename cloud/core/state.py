from fastapi import WebSocket
from typing import Dict, Set

active_devices: Dict[str, WebSocket] = {}
active_clients: Set[WebSocket] = set()
device_metadata: Dict[str, dict] = {}