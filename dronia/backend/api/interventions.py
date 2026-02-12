"""
Interventions routes for the Dronia API
Handles planned interventions for disease detections
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from api.auth import get_current_user, get_database

# Initialize router
router = APIRouter(prefix="/interventions", tags=["Interventions"])

# Security
security = HTTPBearer()


# ============ Pydantic Models ============

class InterventionCreate(BaseModel):
    detectionId: str
    detectionLabel: str
    detectionConfidence: float
    zone: str
    scheduledDate: str  # ISO format date
    scheduledTime: str  # HH:MM format
    interventionType: str
    notes: Optional[str] = None


class InterventionUpdate(BaseModel):
    scheduledDate: Optional[str] = None
    scheduledTime: Optional[str] = None
    interventionType: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None  # pending, inProgress, completed, cancelled


class StatusUpdate(BaseModel):
    status: str  # pending, inProgress, completed, cancelled


class InterventionResponse(BaseModel):
    id: str
    userId: str
    detectionId: str
    detectionLabel: str
    detectionConfidence: float
    zone: str
    scheduledDate: str
    scheduledTime: str
    interventionType: str
    notes: Optional[str] = None
    status: str
    createdAt: datetime
    updatedAt: Optional[datetime] = None


def intervention_to_response(intervention: dict) -> dict:
    """Convert MongoDB intervention document to response format"""
    return {
        "id": str(intervention["_id"]),
        "userId": str(intervention.get("userId", "")),
        "detectionId": intervention.get("detectionId", ""),
        "detectionLabel": intervention.get("detectionLabel", ""),
        "detectionConfidence": intervention.get("detectionConfidence", 0.0),
        "zone": intervention.get("zone", ""),
        "scheduledDate": intervention.get("scheduledDate", ""),
        "scheduledTime": intervention.get("scheduledTime", ""),
        "interventionType": intervention.get("interventionType", ""),
        "notes": intervention.get("notes"),
        "status": intervention.get("status", "pending"),
        "createdAt": intervention.get("createdAt"),
        "updatedAt": intervention.get("updatedAt"),
    }


# ============ Routes ============

@router.get("")
async def get_interventions(
    status: Optional[str] = None,
    user: dict = Depends(get_current_user)
):
    """Get all interventions for the current user"""
    database = await get_database()
    
    query = {"userId": ObjectId(user["_id"])}
    if status:
        query["status"] = status
    
    interventions = await database.interventions.find(query).sort("scheduledDate", 1).to_list(100)
    
    return {
        "success": True,
        "interventions": [intervention_to_response(i) for i in interventions],
        "count": len(interventions)
    }


@router.get("/pending/count")
async def get_pending_count(user: dict = Depends(get_current_user)):
    """Get count of pending interventions for the current user"""
    database = await get_database()
    
    count = await database.interventions.count_documents({
        "userId": ObjectId(user["_id"]),
        "status": "pending"
    })
    
    return {
        "success": True,
        "count": count
    }


@router.get("/{intervention_id}")
async def get_intervention(
    intervention_id: str,
    user: dict = Depends(get_current_user)
):
    """Get a specific intervention by ID"""
    database = await get_database()
    
    try:
        intervention = await database.interventions.find_one({
            "_id": ObjectId(intervention_id),
            "userId": ObjectId(user["_id"])
        })
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid intervention ID")
    
    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention not found")
    
    return {
        "success": True,
        "intervention": intervention_to_response(intervention)
    }


@router.post("")
async def create_intervention(
    request: InterventionCreate,
    user: dict = Depends(get_current_user)
):
    """Create a new intervention"""
    database = await get_database()
    
    intervention_doc = {
        "userId": ObjectId(user["_id"]),
        "detectionId": request.detectionId,
        "detectionLabel": request.detectionLabel,
        "detectionConfidence": request.detectionConfidence,
        "zone": request.zone,
        "scheduledDate": request.scheduledDate,
        "scheduledTime": request.scheduledTime,
        "interventionType": request.interventionType,
        "notes": request.notes,
        "status": "pending",
        "createdAt": datetime.utcnow(),
        "updatedAt": None
    }
    
    result = await database.interventions.insert_one(intervention_doc)
    intervention_doc["_id"] = result.inserted_id
    
    return {
        "success": True,
        "message": "Intervention created successfully",
        "intervention": intervention_to_response(intervention_doc)
    }


@router.put("/{intervention_id}")
async def update_intervention(
    intervention_id: str,
    request: InterventionUpdate,
    user: dict = Depends(get_current_user)
):
    """Update an existing intervention"""
    database = await get_database()
    
    try:
        existing = await database.interventions.find_one({
            "_id": ObjectId(intervention_id),
            "userId": ObjectId(user["_id"])
        })
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid intervention ID")
    
    if not existing:
        raise HTTPException(status_code=404, detail="Intervention not found")
    
    # Build update document
    update_doc = {"updatedAt": datetime.utcnow()}
    
    if request.scheduledDate is not None:
        update_doc["scheduledDate"] = request.scheduledDate
    if request.scheduledTime is not None:
        update_doc["scheduledTime"] = request.scheduledTime
    if request.interventionType is not None:
        update_doc["interventionType"] = request.interventionType
    if request.notes is not None:
        update_doc["notes"] = request.notes
    if request.status is not None:
        if request.status not in ["pending", "inProgress", "completed", "cancelled"]:
            raise HTTPException(status_code=400, detail="Invalid status value")
        update_doc["status"] = request.status
    
    await database.interventions.update_one(
        {"_id": ObjectId(intervention_id)},
        {"$set": update_doc}
    )
    
    updated = await database.interventions.find_one({"_id": ObjectId(intervention_id)})
    
    return {
        "success": True,
        "message": "Intervention updated successfully",
        "intervention": intervention_to_response(updated)
    }


@router.patch("/{intervention_id}/status")
async def update_intervention_status(
    intervention_id: str,
    request: StatusUpdate,
    user: dict = Depends(get_current_user)
):
    """Update only the status of an intervention"""
    status = request.status
    if status not in ["pending", "inProgress", "completed", "cancelled"]:
        raise HTTPException(status_code=400, detail="Invalid status value")
    
    database = await get_database()
    
    try:
        result = await database.interventions.update_one(
            {
                "_id": ObjectId(intervention_id),
                "userId": ObjectId(user["_id"])
            },
            {
                "$set": {
                    "status": status,
                    "updatedAt": datetime.utcnow()
                }
            }
        )
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid intervention ID")
    
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Intervention not found")
    
    return {
        "success": True,
        "message": f"Status updated to {status}"
    }


@router.delete("/{intervention_id}")
async def delete_intervention(
    intervention_id: str,
    user: dict = Depends(get_current_user)
):
    """Delete an intervention"""
    database = await get_database()
    
    try:
        result = await database.interventions.delete_one({
            "_id": ObjectId(intervention_id),
            "userId": ObjectId(user["_id"])
        })
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid intervention ID")
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Intervention not found")
    
    return {
        "success": True,
        "message": "Intervention deleted successfully"
    }
