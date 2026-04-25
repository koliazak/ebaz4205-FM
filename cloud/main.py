import logging
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager


from core.database import init_db
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



@app.get("/")
async def health_check():
    return {
        "status": "online",
        "system": "Zynq Relay Server",
        "message": "Welcome! Use /docs for API documentation."
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )