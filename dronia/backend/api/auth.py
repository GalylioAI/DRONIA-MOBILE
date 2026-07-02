"""
Authentication routes for the Dronia API
Handles user registration, login, and profile management
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime, timedelta
from jose import JWTError, jwt
import bcrypt
from motor.motor_asyncio import AsyncIOMotorClient
from bson import ObjectId
import os

# Initialize router
router = APIRouter(prefix="/auth", tags=["Authentication"])

# Security
security = HTTPBearer()

# JWT Configuration
SECRET_KEY = os.getenv("JWT_SECRET", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30

# MongoDB Configuration
MONGODB_URI = os.getenv("MONGODB_URI", "")
db_client: AsyncIOMotorClient = None
db = None


# ============ Pydantic Models ============

class Location(BaseModel):
    lat: float = 0.0
    lng: float = 0.0


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[Location] = None
    plantTypes: Optional[List[str]] = None
    profileImage: Optional[str] = None
    totalSurface: Optional[float] = None
    soilType: Optional[str] = None


class UpdateProfileRequest(BaseModel):
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[Location] = None
    plantTypes: Optional[List[str]] = None
    profileImage: Optional[str] = None
    totalSurface: Optional[float] = None
    soilType: Optional[str] = None


class UserResponse(BaseModel):
    id: str
    email: str
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[Location] = None
    plantTypes: Optional[List[str]] = None
    profileImage: Optional[str] = None
    totalSurface: Optional[float] = None
    soilType: Optional[str] = None
    role: str = "user"
    plan: str = "free"
    createdAt: Optional[datetime] = None


class UpdatePlanRequest(BaseModel):
    plan: str = Field(..., description="Plan key: free, premium, enterprise")


class AdminUpdatePlanRequest(BaseModel):
    plan: str = Field(..., description="Plan key: free, premium, enterprise")


# ============ Database Functions ============

async def get_database():
    global db_client, db
    if db_client is None:
        if not MONGODB_URI:
            raise HTTPException(
                status_code=500,
                detail="MongoDB URI not configured"
            )
        db_client = AsyncIOMotorClient(MONGODB_URI)
        db = db_client.dronia
    return db


async def init_db():
    """Initialize database connection on startup"""
    global db_client, db
    if MONGODB_URI:
        try:
            db_client = AsyncIOMotorClient(MONGODB_URI)
            db = db_client.dronia
            # Test connection
            await db_client.admin.command('ping')
            print("✅ Connected to MongoDB")
        except Exception as e:
            print(f"❌ MongoDB connection failed: {e}")
            db_client = None
            db = None


async def close_db():
    """Close database connection on shutdown"""
    global db_client
    if db_client:
        db_client.close()
        print("MongoDB connection closed")


# ============ Auth Helpers ============

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password using bcrypt"""
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'),
            hashed_password.encode('utf-8')
        )
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Hash password using bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token and return current user"""
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    database = await get_database()
    user = await database.users.find_one({"_id": ObjectId(user_id)})
    if user is None:
        raise credentials_exception
    
    return user


def user_to_response(user: dict) -> dict:
    """Convert MongoDB user document to response format"""
    return {
        "id": str(user["_id"]),
        "email": user.get("email", ""),
        "firstName": user.get("firstName"),
        "lastName": user.get("lastName"),
        "phone": user.get("phone"),
        "location": user.get("location"),
        "plantTypes": user.get("plantTypes", []),
        "profileImage": user.get("profileImage"),
        "totalSurface": user.get("totalSurface"),
        "soilType": user.get("soilType"),
        "role": user.get("role", "user"),
        "plan": user.get("plan", "free"),
        "createdAt": user.get("createdAt"),
    }


async def require_admin(current_user: dict = Depends(get_current_user)):
    """Dependency that ensures the current user has admin role."""
    if current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès réservé aux administrateurs"
        )
    return current_user


# ============ Routes ============

@router.post("/login")
async def login(request: LoginRequest):
    """Login with email and password, returns JWT token + user (with role and plan)."""
    database = await get_database()

    user = await database.users.find_one({"email": request.email.lower()})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    if not verify_password(request.password, user.get("password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    access_token = create_access_token(data={"sub": str(user["_id"])})

    return {
        "token": access_token,
        "tokens": {
            "accessToken": access_token,
            "refreshToken": access_token,
        },
        "user": user_to_response(user),
        "success": True,
    }


@router.post("/register")
async def register(request: RegisterRequest):
    """Register a new user"""
    database = await get_database()
    
    # Check if user already exists
    existing_user = await database.users.find_one({"email": request.email.lower()})
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte avec cet email existe déjà"
        )
    
    # Validate password length
    if len(request.password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe doit contenir au moins 6 caractères"
        )
    
    # Create user document
    user_doc = {
        "email": request.email.lower(),
        "password": get_password_hash(request.password),
        "firstName": request.firstName or "",
        "lastName": request.lastName or "",
        "phone": request.phone,
        "location": request.location.model_dump() if request.location else None,
        "plantTypes": request.plantTypes or [],
        "profileImage": request.profileImage,
        "totalSurface": request.totalSurface,
        "soilType": request.soilType,
        "role": "user",
        "plan": "free",
        "createdAt": datetime.utcnow(),
    }
    
    # Insert user
    result = await database.users.insert_one(user_doc)
    user_doc["_id"] = result.inserted_id
    
    # Create access token (auto-login after registration)
    access_token = create_access_token(data={"sub": str(result.inserted_id)})
    
    # Return token and user info (matching login response format)
    return {
        "token": access_token,
        "tokens": {
            "accessToken": access_token,
            "refreshToken": access_token  # Use same token for refresh for simplicity
        },
        "user": user_to_response(user_doc),
        "success": True
    }


@router.get("/me")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Get current user profile"""
    return {
        "success": True,
        "data": user_to_response(current_user)
    }


@router.put("/me")
async def update_profile(
    request: UpdateProfileRequest,
    current_user: dict = Depends(get_current_user)
):
    """Update current user profile"""
    database = await get_database()
    
    # Build update document
    update_doc = {}
    if request.firstName is not None:
        update_doc["firstName"] = request.firstName
    if request.lastName is not None:
        update_doc["lastName"] = request.lastName
    if request.phone is not None:
        update_doc["phone"] = request.phone
    if request.location is not None:
        update_doc["location"] = request.location.model_dump()
    if request.plantTypes is not None:
        update_doc["plantTypes"] = request.plantTypes
    if request.profileImage is not None:
        update_doc["profileImage"] = request.profileImage
    if request.totalSurface is not None:
        update_doc["totalSurface"] = request.totalSurface
    if request.soilType is not None:
        update_doc["soilType"] = request.soilType
    
    if update_doc:
        await database.users.update_one(
            {"_id": current_user["_id"]},
            {"$set": update_doc}
        )
    
    # Fetch updated user
    updated_user = await database.users.find_one({"_id": current_user["_id"]})
    
    return {
        "success": True,
        "data": user_to_response(updated_user)
    }


class DeleteAccountRequest(BaseModel):
    confirmationName: str = Field(..., description="User must type their first name to confirm deletion")


@router.delete("/me")
async def delete_account(
    request: DeleteAccountRequest,
    current_user: dict = Depends(get_current_user)
):
    """Delete current user account permanently"""
    database = await get_database()
    
    # Get user's first name for confirmation
    user_first_name = current_user.get("firstName", "").strip().lower()
    confirmation_name = request.confirmationName.strip().lower()
    
    # Verify the confirmation name matches
    if not user_first_name or confirmation_name != user_first_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nom de confirmation ne correspond pas. Veuillez saisir votre prénom exactement."
        )
    
    user_id = current_user["_id"]
    
    # Delete all user's regions
    try:
        await database.regions.delete_many({"userId": str(user_id)})
    except Exception:
        pass  # Regions collection might not exist
    
    # Delete the user account
    result = await database.users.delete_one({"_id": user_id})
    
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Compte non trouvé"
        )
    
    return {
        "success": True,
        "message": "Votre compte a été supprimé définitivement"
    }


# ============ Plan Routes (User) ============

ALLOWED_PLANS = {"free", "premium", "enterprise"}


@router.put("/me/plan")
async def update_my_plan(
    request: UpdatePlanRequest,
    current_user: dict = Depends(get_current_user),
):
    """Allow the logged-in user to choose his subscription plan."""
    plan = request.plan.lower().strip()
    if plan not in ALLOWED_PLANS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Plan invalide. Plans disponibles : {', '.join(sorted(ALLOWED_PLANS))}"
        )

    database = await get_database()
    await database.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"plan": plan, "planUpdatedAt": datetime.utcnow()}}
    )

    updated = await database.users.find_one({"_id": current_user["_id"]})
    return {"success": True, "data": user_to_response(updated)}


# ============ Admin Routes ============

@router.get("/admin/stats")
async def admin_stats(_: dict = Depends(require_admin)):
    """Aggregate stats for the admin dashboard."""
    database = await get_database()
    total_users = await database.users.count_documents({})
    admins = await database.users.count_documents({"role": "admin"})
    free_users = await database.users.count_documents({"plan": {"$in": ["free", None]}})
    premium_users = await database.users.count_documents({"plan": "premium"})
    enterprise_users = await database.users.count_documents({"plan": "enterprise"})
    try:
        analyses_count = await database.analyses.count_documents({})
    except Exception:
        analyses_count = 0
    try:
        regions_count = await database.regions.count_documents({})
    except Exception:
        regions_count = 0

    return {
        "success": True,
        "data": {
            "totalUsers": total_users,
            "admins": admins,
            "plans": {
                "free": free_users,
                "premium": premium_users,
                "enterprise": enterprise_users,
            },
            "analyses": analyses_count,
            "regions": regions_count,
        }
    }


@router.get("/admin/users")
async def admin_list_users(_: dict = Depends(require_admin)):
    """List every registered user with role + plan."""
    database = await get_database()
    cursor = database.users.find().sort("createdAt", -1)
    users = [user_to_response(u) async for u in cursor]
    return {"success": True, "data": users}


@router.put("/admin/users/{user_id}/plan")
async def admin_update_user_plan(
    user_id: str,
    request: AdminUpdatePlanRequest,
    _: dict = Depends(require_admin),
):
    """Admin changes a user's subscription plan."""
    plan = request.plan.lower().strip()
    if plan not in ALLOWED_PLANS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Plan invalide. Plans disponibles : {', '.join(sorted(ALLOWED_PLANS))}"
        )

    database = await get_database()
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Identifiant utilisateur invalide")

    result = await database.users.update_one(
        {"_id": oid},
        {"$set": {"plan": plan, "planUpdatedAt": datetime.utcnow()}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    updated = await database.users.find_one({"_id": oid})
    return {"success": True, "data": user_to_response(updated)}


@router.delete("/admin/users/{user_id}")
async def admin_delete_user(
    user_id: str,
    current_admin: dict = Depends(require_admin),
):
    """Admin removes a user account."""
    database = await get_database()
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Identifiant utilisateur invalide")

    if oid == current_admin["_id"]:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas supprimer votre propre compte admin")

    result = await database.users.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    return {"success": True, "message": "Utilisateur supprimé"}
