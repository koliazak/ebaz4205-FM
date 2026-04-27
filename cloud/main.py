import logging
import os

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from starlette.responses import FileResponse
from starlette.staticfiles import StaticFiles

from core.database import init_db, add_user
from routers import device_api, client_api


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - [%(name)s] - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Код тут виконається ПРИ СТАРТІ сервера
    logger.info("Starting Relay Server...")
    logger.info("Starting SQLite...")
    await init_db()
    yield

    logger.info("Stopping Relay Server...")


app = FastAPI(
    title="Zynq FM Radio Relay",
    description="Secure IoT Relay for Audio Streaming and Control",
    version="1.0.0",
    lifespan=lifespan
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(
    device_api.router,
    tags=["Hardware"],
    prefix=""
)

app.include_router(
    client_api.router,
    tags=["Web Client"],
    prefix=""
)

@app.get("/ping")
async def health_check():
    return {
        "status": "online",
        "system": "Zynq Relay Server",
        "message": "Welcome! Use /docs for API documentation."
    }

BASE_DIR = os.path.dirname(__file__)
FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")
STATIC_DIR = os.path.join(FRONTEND_DIR, "static")

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
@app.get("/")
async def serve_frontend():
    return FileResponse(os.path.join(FRONTEND_DIR, "index.html"))

@app.get("/api/auth/refresh")
async def refresh_token(token: str):
    # Тут ти перевіряєш старий токен і, якщо він валідний, видаєш новий на 15 хв.
    # Для простоти зараз можна просто попросити юзера перелогінитись.
    pass


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )