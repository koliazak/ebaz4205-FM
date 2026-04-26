import aiosqlite
from typing import Optional

DB_FILE = "relay_server.db"


async def init_db():
    async with aiosqlite.connect(DB_FILE) as db:
        await db.execute("PRAGMA journal_mode=WAL;")

        await db.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL
            )
        """)

        await db.execute("""
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                device_secret TEXT NOT NULL,
                is_active BOOLEAN DEFAULT 1
            )
        """)

        await db.commit()


async def add_user(username, hashed_password) -> Optional[aiosqlite.IntegrityError]:
    async with aiosqlite.connect(DB_FILE) as db:
        await db.execute("INSERT INTO users (username, password_hash) VALUES(?, ?) ", (username, hashed_password))
        await db.commit()


async def find_user(username) -> Optional[dict]:
    async with aiosqlite.connect(DB_FILE) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("SELECT * FROM users WHERE username = ?", (username,))
        db_user = await cursor.fetchone()
        return db_user

async def find_device(device_id) -> Optional[dict]:
    async with aiosqlite.connect(DB_FILE) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,))
        db_device = await cursor.fetchone()
        return db_device