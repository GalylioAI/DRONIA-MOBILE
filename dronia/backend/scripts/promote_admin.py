"""
Promeut un utilisateur existant au rôle administrateur (role=admin) dans MongoDB.

Usage :
    cd dronia/backend
    export MONGODB_URI="mongodb+srv://...."   # ou laisser lire depuis ../.env
    python scripts/promote_admin.py email@exemple.com

L'utilisateur doit déjà exister (s'inscrire via l'app d'abord).
Une fois promu, il sera redirigé vers le tableau de bord admin à la prochaine connexion.
"""

import os
import sys
import asyncio
from pathlib import Path

from motor.motor_asyncio import AsyncIOMotorClient

try:
    from dotenv import load_dotenv
    # Charge dronia/.env puis dronia/backend/.env si présents
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
except Exception:
    pass


async def promote(email: str) -> None:
    uri = os.getenv("MONGODB_URI", "")
    if not uri:
        print("❌ MONGODB_URI non défini (export MONGODB_URI=... ou dans .env)")
        sys.exit(1)

    client = AsyncIOMotorClient(uri)
    db = client.dronia

    user = await db.users.find_one({"email": email.lower().strip()})
    if not user:
        print(f"❌ Aucun utilisateur avec l'email : {email}")
        print("   → Inscris-toi d'abord dans l'application, puis relance ce script.")
        sys.exit(1)

    result = await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"role": "admin"}},
    )
    if result.modified_count == 1:
        print(f"✅ {email} est maintenant administrateur.")
    else:
        print(f"ℹ️  {email} était déjà administrateur (aucune modification).")

    client.close()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage : python scripts/promote_admin.py email@exemple.com")
        sys.exit(1)
    asyncio.run(promote(sys.argv[1]))
