"""
Analyses routes for the Dronia API
Handles storage and retrieval of user analysis history
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from bson import ObjectId
from api.auth import get_current_user, get_database

# Initialize router
router = APIRouter(prefix="/analyses", tags=["Analyses"])


# ============ Pydantic Models ============

class AnalysisResultItem(BaseModel):
    className: str
    confidence: float
    diseaseName: Optional[str] = None
    diseaseNameFr: Optional[str] = None
    isHealthy: bool = False


class WeatherData(BaseModel):
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    windSpeed: Optional[float] = None
    description: Optional[str] = None


class SoilConditions(BaseModel):
    humidity: Optional[float] = None
    temperature: Optional[float] = None


class AnalysisCreate(BaseModel):
    imageBase64: Optional[str] = None
    imagePath: Optional[str] = None
    cropType: str
    region: Optional[str] = None
    notes: Optional[str] = None
    symptoms: Optional[str] = None
    suspectedDisease: Optional[str] = None
    analysisMode: str = "efficientnet"
    results: List[AnalysisResultItem]
    healthScore: float
    healthStatus: str
    affectedSurface: Optional[float] = None
    estimatedYieldLoss: Optional[float] = None
    propagationRate: Optional[float] = None
    riskLevel: Optional[str] = None
    weather: Optional[WeatherData] = None
    soilConditions: Optional[SoilConditions] = None
    recommendations: Optional[List[str]] = None


class AnalysisUpdate(BaseModel):
    notes: Optional[str] = None
    region: Optional[str] = None


class AnalysisResponse(BaseModel):
    id: str
    userId: str
    imageBase64: Optional[str] = None
    imagePath: Optional[str] = None
    cropType: str
    region: Optional[str] = None
    notes: Optional[str] = None
    symptoms: Optional[str] = None
    suspectedDisease: Optional[str] = None
    analysisMode: str
    results: List[dict]
    healthScore: float
    healthStatus: str
    affectedSurface: Optional[float] = None
    estimatedYieldLoss: Optional[float] = None
    propagationRate: Optional[float] = None
    riskLevel: Optional[str] = None
    weather: Optional[dict] = None
    soilConditions: Optional[dict] = None
    recommendations: Optional[List[str]] = None
    createdAt: datetime


# Insect Analysis Models
class InsectDetection(BaseModel):
    className: str
    confidence: float
    bbox: Optional[dict] = None
    dangerLevel: Optional[str] = None
    impact: Optional[str] = None
    treatment: Optional[str] = None
    prevention: Optional[str] = None


class InsectAnalysisCreate(BaseModel):
    imageBase64: Optional[str] = None
    imagePath: Optional[str] = None
    detections: List[InsectDetection]
    totalCount: int
    dangerLevel: str
    hasInsects: bool
    notes: Optional[str] = None
    location: Optional[str] = None


class InsectAnalysisResponse(BaseModel):
    id: str
    userId: str
    imageBase64: Optional[str] = None
    imagePath: Optional[str] = None
    detections: List[dict]
    totalCount: int
    dangerLevel: str
    hasInsects: bool
    notes: Optional[str] = None
    location: Optional[str] = None
    createdAt: datetime


# ============ Helper Functions ============

def analysis_to_response(analysis: dict) -> dict:
    """Convert MongoDB analysis document to response format"""
    return {
        "id": str(analysis["_id"]),
        "userId": str(analysis.get("userId", "")),
        "imageBase64": analysis.get("imageBase64"),
        "imagePath": analysis.get("imagePath"),
        "cropType": analysis.get("cropType", ""),
        "region": analysis.get("region"),
        "notes": analysis.get("notes"),
        "symptoms": analysis.get("symptoms"),
        "suspectedDisease": analysis.get("suspectedDisease"),
        "analysisMode": analysis.get("analysisMode", "efficientnet"),
        "results": analysis.get("results", []),
        "healthScore": analysis.get("healthScore", 0),
        "healthStatus": analysis.get("healthStatus", "Sain"),
        "affectedSurface": analysis.get("affectedSurface"),
        "estimatedYieldLoss": analysis.get("estimatedYieldLoss"),
        "propagationRate": analysis.get("propagationRate"),
        "riskLevel": analysis.get("riskLevel"),
        "weather": analysis.get("weather"),
        "soilConditions": analysis.get("soilConditions"),
        "recommendations": analysis.get("recommendations"),
        "createdAt": analysis.get("createdAt"),
    }


def prediction_to_analysis_response(prediction: dict) -> dict:
    """Convert web app Prediction document to mobile Analysis format"""
    result = prediction.get("result", {})
    
    disease_name = result.get("disease", "Aucune")
    is_healthy = disease_name == "Aucune" or result.get("generalStatus") == "Saine"
    health_status = "Sain" if is_healthy else "Maladie"
    confidence = result.get("confidence", 0)
    
    results = [{
        "className": result.get("diseaseClass", disease_name),
        "confidence": confidence,
        "diseaseName": disease_name,
        "diseaseNameFr": disease_name,
        "isHealthy": is_healthy
    }]
    
    return {
        "id": str(prediction.get("_id", "")),
        "userId": str(prediction.get("userId", "")),
        "imageBase64": prediction.get("image"),
        "imagePath": None,
        "cropType": result.get("plantType", prediction.get("region", "Inconnu")),
        "region": prediction.get("region"),
        "notes": None,
        "symptoms": None,
        "suspectedDisease": prediction.get("diseaseSuspected") or disease_name,
        "analysisMode": result.get("predictionSource", "tensorflow"),
        "results": results,
        "healthScore": confidence * 100 if is_healthy else (100 - confidence * 100),
        "healthStatus": health_status,
        "affectedSurface": result.get("affectedSurface"),
        "estimatedYieldLoss": None,
        "propagationRate": None,
        "riskLevel": result.get("severity", "Faible"),
        "weather": result.get("weather"),
        "soilConditions": None,
        "recommendations": [result.get("recommendations", {}).get("treatment", ""), 
                           result.get("recommendations", {}).get("prevention", "")] if result.get("recommendations") else None,
        "createdAt": prediction.get("createdAt"),
    }


def insect_analysis_to_response(analysis: dict) -> dict:
    """Convert MongoDB insect analysis document to response format"""
    return {
        "id": str(analysis["_id"]),
        "userId": str(analysis.get("userId", "")),
        "imageBase64": analysis.get("imageBase64"),
        "imagePath": analysis.get("imagePath"),
        "detections": analysis.get("detections", []),
        "totalCount": analysis.get("totalCount", 0),
        "dangerLevel": analysis.get("dangerLevel", "Aucun"),
        "hasInsects": analysis.get("hasInsects", False),
        "notes": analysis.get("notes"),
        "location": analysis.get("location"),
        "createdAt": analysis.get("createdAt"),
    }


# ============ Disease Analysis Routes ============

@router.get("")
async def get_analyses(
    status: Optional[str] = None,
    cropType: Optional[str] = None,
    limit: int = 50,
    skip: int = 0,
    user: dict = Depends(get_current_user)
):
    """Get all analyses for the current user with optional filters"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    query = {"userId": user_id}
    if status:
        query["healthStatus"] = status
    if cropType:
        query["cropType"] = cropType
    
    analyses = await database.analyses.find(query).sort(
        "createdAt", -1
    ).skip(skip).limit(limit).to_list(limit)
    
    prediction_query = {"userId": user_id}
    if status:
        if status == "Sain":
            prediction_query["result.generalStatus"] = "Saine"
        else:
            prediction_query["result.generalStatus"] = {"$ne": "Saine"}
    
    predictions = await database.predictions.find(prediction_query).sort(
        "createdAt", -1
    ).skip(skip).limit(limit).to_list(limit)
    
    all_analyses = [analysis_to_response(a) for a in analyses]
    all_analyses.extend([prediction_to_analysis_response(p) for p in predictions])
    all_analyses.sort(key=lambda x: x.get("createdAt") or datetime.min, reverse=True)
    all_analyses = all_analyses[:limit]
    
    total_analyses = await database.analyses.count_documents({"userId": user_id})
    total_predictions = await database.predictions.count_documents({"userId": user_id})
    total = total_analyses + total_predictions
    
    return {
        "success": True,
        "analyses": all_analyses,
        "count": len(all_analyses),
        "total": total
    }


@router.get("/stats")
async def get_analysis_stats(user: dict = Depends(get_current_user)):
    """Get analysis statistics for the current user"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    total_analyses = await database.analyses.count_documents({"userId": user_id})
    healthy_analyses = await database.analyses.count_documents({
        "userId": user_id, "healthStatus": "Sain"
    })
    disease_analyses = await database.analyses.count_documents({
        "userId": user_id, "healthStatus": "Maladie"
    })
    stress_analyses = await database.analyses.count_documents({
        "userId": user_id, "healthStatus": "Stress"
    })
    
    total_predictions = await database.predictions.count_documents({"userId": user_id})
    healthy_predictions = await database.predictions.count_documents({
        "userId": user_id, "result.generalStatus": "Saine"
    })
    disease_predictions = await database.predictions.count_documents({
        "userId": user_id, "result.generalStatus": {"$ne": "Saine"}
    })
    
    total = total_analyses + total_predictions
    healthy = healthy_analyses + healthy_predictions
    disease = disease_analyses + disease_predictions
    stress = stress_analyses
    
    crop_stats = await database.analyses.aggregate([
        {"$match": {"userId": user_id}},
        {"$group": {"_id": "$cropType", "count": {"$sum": 1}}}
    ]).to_list(100)
    
    plant_stats = await database.predictions.aggregate([
        {"$match": {"userId": user_id}},
        {"$group": {"_id": "$result.plantType", "count": {"$sum": 1}}}
    ]).to_list(100)
    
    crop_dict = {item["_id"]: item["count"] for item in crop_stats if item["_id"]}
    for item in plant_stats:
        if item["_id"]:
            crop_dict[item["_id"]] = crop_dict.get(item["_id"], 0) + item["count"]
    
    return {
        "success": True,
        "stats": {
            "total": total,
            "healthy": healthy,
            "disease": disease,
            "stress": stress,
            "byCropType": crop_dict
        }
    }


# ============ INSECT ANALYSIS ROUTES (MUST BE BEFORE /{analysis_id}) ============

@router.get("/insects")
async def get_insect_analyses(
    hasInsects: Optional[bool] = None,
    dangerLevel: Optional[str] = None,
    limit: int = 50,
    skip: int = 0,
    user: dict = Depends(get_current_user)
):
    """Get all insect analyses for the current user with optional filters"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    query = {"userId": user_id}
    if hasInsects is not None:
        query["hasInsects"] = hasInsects
    if dangerLevel:
        query["dangerLevel"] = dangerLevel
    
    analyses = await database.insect_analyses.find(query).sort(
        "createdAt", -1
    ).skip(skip).limit(limit).to_list(limit)
    
    total = await database.insect_analyses.count_documents({"userId": user_id})
    
    return {
        "success": True,
        "analyses": [insect_analysis_to_response(a) for a in analyses],
        "count": len(analyses),
        "total": total
    }


@router.get("/insects/stats")
async def get_insect_analysis_stats(user: dict = Depends(get_current_user)):
    """Get insect analysis statistics for the current user"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    total_analyses = await database.insect_analyses.count_documents({"userId": user_id})
    analyses_with_insects = await database.insect_analyses.count_documents({
        "userId": user_id, "hasInsects": True
    })
    
    pipeline = [
        {"$match": {"userId": user_id}},
        {"$group": {"_id": None, "totalInsects": {"$sum": "$totalCount"}}}
    ]
    result = await database.insect_analyses.aggregate(pipeline).to_list(1)
    total_insects = result[0]["totalInsects"] if result else 0
    
    danger_stats = await database.insect_analyses.aggregate([
        {"$match": {"userId": user_id}},
        {"$group": {"_id": "$dangerLevel", "count": {"$sum": 1}}}
    ]).to_list(100)
    
    danger_distribution = {item["_id"]: item["count"] for item in danger_stats if item["_id"]}
    
    insect_stats = await database.insect_analyses.aggregate([
        {"$match": {"userId": user_id, "hasInsects": True}},
        {"$unwind": "$detections"},
        {"$group": {"_id": "$detections.className", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": 10}
    ]).to_list(10)
    
    top_insects = [{"name": item["_id"], "count": item["count"]} for item in insect_stats if item["_id"]]
    
    return {
        "success": True,
        "stats": {
            "totalAnalyses": total_analyses,
            "analysesWithInsects": analyses_with_insects,
            "totalInsectsDetected": total_insects,
            "dangerDistribution": danger_distribution,
            "topInsects": top_insects
        }
    }


@router.post("/insects")
async def create_insect_analysis(
    request: InsectAnalysisCreate,
    user: dict = Depends(get_current_user)
):
    """Save a new insect analysis result"""
    database = await get_database()
    
    detections_list = [
        {
            "className": d.className,
            "confidence": d.confidence,
            "bbox": d.bbox,
            "dangerLevel": d.dangerLevel,
            "impact": d.impact,
            "treatment": d.treatment,
            "prevention": d.prevention
        }
        for d in request.detections
    ]
    
    analysis_doc = {
        "userId": ObjectId(user["_id"]),
        "imageBase64": request.imageBase64,
        "imagePath": request.imagePath,
        "detections": detections_list,
        "totalCount": request.totalCount,
        "dangerLevel": request.dangerLevel,
        "hasInsects": request.hasInsects,
        "notes": request.notes,
        "location": request.location,
        "createdAt": datetime.utcnow()
    }
    
    result = await database.insect_analyses.insert_one(analysis_doc)
    analysis_doc["_id"] = result.inserted_id
    
    return {
        "success": True,
        "message": "Insect analysis saved successfully",
        "analysis": insect_analysis_to_response(analysis_doc)
    }


@router.delete("/insects")
async def delete_all_insect_analyses(user: dict = Depends(get_current_user)):
    """Delete all insect analyses for the current user"""
    database = await get_database()
    
    result = await database.insect_analyses.delete_many({
        "userId": ObjectId(user["_id"])
    })
    
    return {
        "success": True,
        "message": f"Deleted {result.deleted_count} insect analyses"
    }


@router.get("/insects/{analysis_id}")
async def get_insect_analysis(
    analysis_id: str,
    user: dict = Depends(get_current_user)
):
    """Get a specific insect analysis by ID"""
    database = await get_database()
    
    try:
        analysis = await database.insect_analyses.find_one({
            "_id": ObjectId(analysis_id),
            "userId": ObjectId(user["_id"])
        })
        
        if not analysis:
            raise HTTPException(status_code=404, detail="Insect analysis not found")
        
        return {
            "success": True,
            "analysis": insect_analysis_to_response(analysis)
        }
        
    except Exception as e:
        if "not found" in str(e).lower():
            raise
        raise HTTPException(status_code=400, detail="Invalid analysis ID")


@router.delete("/insects/{analysis_id}")
async def delete_insect_analysis(
    analysis_id: str,
    user: dict = Depends(get_current_user)
):
    """Delete an insect analysis"""
    database = await get_database()
    
    try:
        result = await database.insect_analyses.delete_one({
            "_id": ObjectId(analysis_id),
            "userId": ObjectId(user["_id"])
        })
        
        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Insect analysis not found")
        
        return {
            "success": True,
            "message": "Insect analysis deleted successfully"
        }
        
    except Exception as e:
        if "not found" in str(e).lower():
            raise
        raise HTTPException(status_code=400, detail="Invalid analysis ID")


# ============ Generic Analysis Routes (with {analysis_id} - MUST BE LAST) ============

@router.get("/{analysis_id}")
async def get_analysis(
    analysis_id: str,
    user: dict = Depends(get_current_user)
):
    """Get a specific analysis by ID - checks both collections"""
    database = await get_database()
    
    try:
        analysis = await database.analyses.find_one({
            "_id": ObjectId(analysis_id),
            "userId": ObjectId(user["_id"])
        })
        
        if analysis:
            return {
                "success": True,
                "analysis": analysis_to_response(analysis)
            }
        
        prediction = await database.predictions.find_one({
            "_id": ObjectId(analysis_id),
            "userId": ObjectId(user["_id"])
        })
        
        if prediction:
            return {
                "success": True,
                "analysis": prediction_to_analysis_response(prediction)
            }
        
        raise HTTPException(status_code=404, detail="Analysis not found")
        
    except Exception as e:
        if "not found" in str(e).lower():
            raise
        raise HTTPException(status_code=400, detail="Invalid analysis ID")


@router.post("")
async def create_analysis(
    request: AnalysisCreate,
    user: dict = Depends(get_current_user)
):
    """Save a new analysis result"""
    database = await get_database()
    
    results_list = [
        {
            "className": r.className,
            "confidence": r.confidence,
            "diseaseName": r.diseaseName,
            "diseaseNameFr": r.diseaseNameFr,
            "isHealthy": r.isHealthy
        }
        for r in request.results
    ]
    
    analysis_doc = {
        "userId": ObjectId(user["_id"]),
        "imageBase64": request.imageBase64,
        "imagePath": request.imagePath,
        "cropType": request.cropType,
        "region": request.region,
        "notes": request.notes,
        "symptoms": request.symptoms,
        "suspectedDisease": request.suspectedDisease,
        "analysisMode": request.analysisMode,
        "results": results_list,
        "healthScore": request.healthScore,
        "healthStatus": request.healthStatus,
        "affectedSurface": request.affectedSurface,
        "estimatedYieldLoss": request.estimatedYieldLoss,
        "propagationRate": request.propagationRate,
        "riskLevel": request.riskLevel,
        "weather": request.weather.dict() if request.weather else None,
        "soilConditions": request.soilConditions.dict() if request.soilConditions else None,
        "recommendations": request.recommendations,
        "createdAt": datetime.utcnow()
    }
    
    result = await database.analyses.insert_one(analysis_doc)
    analysis_doc["_id"] = result.inserted_id
    
    return {
        "success": True,
        "message": "Analysis saved successfully",
        "analysis": analysis_to_response(analysis_doc)
    }


@router.put("/{analysis_id}")
async def update_analysis(
    analysis_id: str,
    request: AnalysisUpdate,
    user: dict = Depends(get_current_user)
):
    """Update an existing analysis (notes, region)"""
    database = await get_database()
    
    try:
        existing = await database.analyses.find_one({
            "_id": ObjectId(analysis_id),
            "userId": ObjectId(user["_id"])
        })
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid analysis ID")
    
    if not existing:
        raise HTTPException(status_code=404, detail="Analysis not found")
    
    update_doc = {}
    if request.notes is not None:
        update_doc["notes"] = request.notes
    if request.region is not None:
        update_doc["region"] = request.region
    
    if update_doc:
        await database.analyses.update_one(
            {"_id": ObjectId(analysis_id)},
            {"$set": update_doc}
        )
    
    updated = await database.analyses.find_one({"_id": ObjectId(analysis_id)})
    
    return {
        "success": True,
        "message": "Analysis updated successfully",
        "analysis": analysis_to_response(updated)
    }


@router.delete("/{analysis_id}")
async def delete_analysis(
    analysis_id: str,
    user: dict = Depends(get_current_user)
):
    """Delete an analysis (from either analyses or predictions collection)"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    try:
        obj_id = ObjectId(analysis_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid analysis ID")
    
    result = await database.analyses.delete_one({
        "_id": obj_id,
        "userId": user_id
    })
    
    if result.deleted_count == 0:
        result = await database.predictions.delete_one({
            "_id": obj_id,
            "userId": user_id
        })
    
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Analysis not found")
    
    return {
        "success": True,
        "message": "Analysis deleted successfully"
    }


@router.delete("")
async def delete_all_analyses(user: dict = Depends(get_current_user)):
    """Delete all analyses for the current user (from both collections)"""
    database = await get_database()
    user_id = ObjectId(user["_id"])
    
    analyses_result = await database.analyses.delete_many({"userId": user_id})
    predictions_result = await database.predictions.delete_many({"userId": user_id})
    
    total_deleted = analyses_result.deleted_count + predictions_result.deleted_count
    
    return {
        "success": True,
        "message": f"Deleted {total_deleted} analyses"
    }
