"""
Create (or promote) the DronIA admin test account.

Usage:
    cd backend
    source venv/bin/activate
    python scripts/create_admin.py

The MONGODB_URI environment variable must be set (.env at repo root).
Default credentials below match what is documented in the report.
"""

import asyncio
import os
import sys
from datetime import datetime

import bcrypt
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient


load_dotenv()

ADMIN_EMAIL = "admin@dronia.tn"
ADMIN_PASSWORD = "Admin@DronIA2026"
ADMIN_FIRST_NAME = "Admin"
ADMIN_LAST_NAME = "DronIA"


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


async def main() -> int:
    uri = os.getenv("MONGODB_URI")
    if not uri:
        print("❌ MONGODB_URI is not set. Add it to dronia/.env first.")
        return 1

    client = AsyncIOMotorClient(uri)
    db = client.dronia

    now = datetime.utcnow()
    update_doc = {
        "role": "admin",
        "plan": "enterprise",
        "firstName": ADMIN_FIRST_NAME,
        "lastName": ADMIN_LAST_NAME,
        "updatedAt": now,
    }
    set_on_insert = {
        "email": ADMIN_EMAIL,
        "password": hash_password(ADMIN_PASSWORD),
        "createdAt": now,
        "plantTypes": [],
    }

    result = await db.users.update_one(
        {"email": ADMIN_EMAIL},
        {"$set": update_doc, "$setOnInsert": set_on_insert},
        upsert=True,
    )

    if result.upserted_id is not None:
        print(f"✅ Admin account created: {ADMIN_EMAIL}")
    else:
        # Account already existed, refresh the password so the test creds work.
        await db.users.update_one(
            {"email": ADMIN_EMAIL},
            {"$set": {"password": hash_password(ADMIN_PASSWORD), "role": "admin"}},
        )
        print(f"✅ Admin account refreshed: {ADMIN_EMAIL}")

    print()
    print("Test admin credentials")
    print(f"  Email    : {ADMIN_EMAIL}")
    print(f"  Password : {ADMIN_PASSWORD}")
    print()
    print("Login from the regular DronIA login screen, the app will detect the admin role and open the admin dashboard.")

    client.close()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
