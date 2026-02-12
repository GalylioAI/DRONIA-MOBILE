"""
Regions API for the Dronia App
Handles saving and retrieving user agricultural regions
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from bson import ObjectId

from api.auth import get_current_user, get_database

# Initialize router
router = APIRouter(prefix="/regions", tags=["Regions"])


# ============ Pydantic Models ============

class PointModel(BaseModel):
    lat: float
    lng: float


class RegionCreate(BaseModel):
    name: str
    points: List[PointModel]
    hectares: float
    color: int  # Color value as integer
    humidity: Optional[int] = 60
    temperature: Optional[int] = 25


class RegionUpdate(BaseModel):
    name: Optional[str] = None
    points: Optional[List[PointModel]] = None
    hectares: Optional[float] = None
    color: Optional[int] = None
    humidity: Optional[int] = None
    temperature: Optional[int] = None


class RegionResponse(BaseModel):
    id: str
    name: str
    points: List[PointModel]
    hectares: float
    color: int
    humidity: int
    temperature: int
    createdAt: datetime
    updatedAt: Optional[datetime] = None


# ============ Helper Functions ============

def region_to_response(region: dict) -> dict:
    """Convert MongoDB region document to response format"""
    return {
        "id": str(region["_id"]),
        "name": region.get("name", ""),
        "points": region.get("points", []),
        "hectares": region.get("hectares", 0.0),
        "color": region.get("color", 0xFF4CAF50),
        "humidity": region.get("humidity", 60),
        "temperature": region.get("temperature", 25),
        "createdAt": region.get("createdAt", datetime.utcnow()),
        "updatedAt": region.get("updatedAt"),
    }


# ============ Routes ============

@router.get("")
async def get_regions(current_user: dict = Depends(get_current_user)):
    """Get all regions for the current user"""
    database = await get_database()
    user_id = str(current_user["_id"])
    
    # Find all regions for this user
    cursor = database.regions.find({"userId": user_id})
    regions = await cursor.to_list(length=100)
    
    return {
        "regions": [region_to_response(r) for r in regions],
        "count": len(regions),
        "totalHectares": sum(r.get("hectares", 0) for r in regions)
    }


@router.post("")
async def create_region(
    region: RegionCreate,
    current_user: dict = Depends(get_current_user)
):
    """Create a new region for the current user"""
    database = await get_database()
    user_id = str(current_user["_id"])
    
    # Create region document
    region_doc = {
        "userId": user_id,
        "name": region.name,
        "points": [{"lat": p.lat, "lng": p.lng} for p in region.points],
        "hectares": region.hectares,
        "color": region.color,
        "humidity": region.humidity or 60,
        "temperature": region.temperature or 25,
        "createdAt": datetime.utcnow(),
    }
    
    # Insert region
    result = await database.regions.insert_one(region_doc)
    region_doc["_id"] = result.inserted_id
    
    print(f"✅ Created region '{region.name}' for user {user_id}")
    
    return region_to_response(region_doc)


@router.put("/{region_id}")
async def update_region(
    region_id: str,
    region: RegionUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update an existing region"""
    database = await get_database()
    user_id = str(current_user["_id"])
    
    # Find the region
    existing_region = await database.regions.find_one({
        "_id": ObjectId(region_id),
        "userId": user_id
    })
    
    if not existing_region:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Région non trouvée"
        )
    
    # Build update document
    update_doc = {"updatedAt": datetime.utcnow()}
    if region.name is not None:
        update_doc["name"] = region.name
    if region.points is not None:
        update_doc["points"] = [{"lat": p.lat, "lng": p.lng} for p in region.points]
    if region.hectares is not None:
        update_doc["hectares"] = region.hectares
    if region.color is not None:
        update_doc["color"] = region.color
    if region.humidity is not None:
        update_doc["humidity"] = region.humidity
    if region.temperature is not None:
        update_doc["temperature"] = region.temperature
    
    # Update region
    await database.regions.update_one(
        {"_id": ObjectId(region_id)},
        {"$set": update_doc}
    )
    
    # Get updated region
    updated_region = await database.regions.find_one({"_id": ObjectId(region_id)})
    
    return region_to_response(updated_region)


@router.delete("/{region_id}")
async def delete_region(
    region_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete a region"""
    database = await get_database()
    user_id = str(current_user["_id"])
    
    # Find and delete the region
    result = await database.regions.delete_one({
        "_id": ObjectId(region_id),
        "userId": user_id
    })
    
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Région non trouvée"
        )
    
    print(f"🗑️ Deleted region {region_id} for user {user_id}")
    
    return {"message": "Région supprimée avec succès"}


@router.delete("")
async def delete_all_regions(current_user: dict = Depends(get_current_user)):
    """Delete all regions for the current user"""
    database = await get_database()
    user_id = str(current_user["_id"])
    
    result = await database.regions.delete_many({"userId": user_id})
    
    print(f"🗑️ Deleted {result.deleted_count} regions for user {user_id}")
    
    return {
        "message": f"{result.deleted_count} région(s) supprimée(s)",
        "deletedCount": result.deleted_count
    }
