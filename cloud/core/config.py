from dataclasses import dataclass
import json
from dotenv import dotenv_values

jwt_secret = dotenv_values("core/.env")

@dataclass
class Config:
    JWT_SECRET: str
    ALGORITHM: str
    CLOCK_SKEW_TOLERANCE: int # sec
    EXPECTED_ISSUER: str
    EXPECTED_AUDIENCE: str
    ACCESS_TOKEN_LIFETIME: int # sec
    NONCE_TTL: int # sec

with open("core/config.json", "r") as f:
    json_obj = json.loads(f.read())

config = Config(**jwt_secret,**json_obj)
