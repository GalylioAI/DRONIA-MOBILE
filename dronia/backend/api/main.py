"""
FastAPI application for YOLOv8 plant disease detection
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from pathlib import Path
import uvicorn
import os
from dotenv import load_dotenv
import base64
import io
from PIL import Image
import numpy as np

from ultralytics import YOLO
from utils.logger import setup_logger
from utils.image_analysis import analyze_leaf_health
import torch
from torchvision import transforms
import yaml
import gc
import os

# Optimize PyTorch for low memory usage
torch.set_num_threads(1)  # Use single thread to reduce memory
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'
# Disable PyTorch JIT to save memory
torch.jit.set_fusion_strategy([])

# Load environment variables
load_dotenv()

# Initialize logger
logger = setup_logger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Dronia API",
    description="Complete API for Dronia mobile app - Authentication & Plant Disease Detection",
    version="2.0.0"
)

# CORS middleware - allow all origins for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import and include auth router
from api.auth import router as auth_router, init_db, close_db
from api.regions import router as regions_router
from api.interventions import router as interventions_router
from api.analyses import router as analyses_router
from api.dataset import router as dataset_router
app.include_router(auth_router)
app.include_router(regions_router)
app.include_router(interventions_router)
app.include_router(analyses_router)
app.include_router(dataset_router)

# Startup/shutdown events for database
@app.on_event("startup")
async def startup_event():
    await init_db()

@app.on_event("shutdown")
async def shutdown_event():
    await close_db()


# ============ Privacy Policy ============
@app.get("/privacy", response_class=HTMLResponse)
async def privacy_policy():
    """Privacy policy page for Google Play Store"""
    return """
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DronIA - Politique de Confidentialité</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; color: #333; background: #f9f9f9; }
        h1 { color: #2e7d32; border-bottom: 2px solid #2e7d32; padding-bottom: 10px; }
        h2 { color: #388e3c; margin-top: 30px; }
        .date { color: #666; font-style: italic; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        ul { padding-left: 20px; }
        li { margin-bottom: 8px; }
        a { color: #2e7d32; }
    </style>
</head>
<body>
<div class="container">
    <h1>🌿 DronIA - Politique de Confidentialité</h1>
    <p class="date">Dernière mise à jour : 16 février 2026</p>

    <h2>1. Introduction</h2>
    <p>DronIA est une application mobile d'agronomie de précision utilisant l'intelligence artificielle pour la détection des maladies des plantes. La présente politique de confidentialité décrit comment nous collectons, utilisons et protégeons vos données personnelles.</p>

    <h2>2. Données collectées</h2>
    <p>L'application DronIA peut collecter les données suivantes :</p>
    <ul>
        <li><strong>Photos et images</strong> : Les photos prises via l'appareil photo ou sélectionnées depuis la galerie sont envoyées à notre serveur pour l'analyse par intelligence artificielle. Ces images sont traitées en temps réel et ne sont pas stockées de manière permanente sur nos serveurs.</li>
        <li><strong>Données de localisation</strong> : Avec votre autorisation, nous collectons votre position GPS pour géolocaliser vos parcelles agricoles et fournir des données météorologiques locales.</li>
        <li><strong>Informations de compte</strong> : Si vous créez un compte, nous stockons votre adresse email et vos identifiants de connexion (mot de passe chiffré).</li>
        <li><strong>Données d'analyse</strong> : L'historique de vos scans de maladies et les rapports générés sont stockés dans votre compte.</li>
        <li><strong>Données météorologiques</strong> : Nous utilisons votre localisation pour récupérer les données météo via des services tiers (OpenWeather).</li>
    </ul>

    <h2>3. Utilisation des données</h2>
    <p>Vos données sont utilisées exclusivement pour :</p>
    <ul>
        <li>Analyser les images de plantes et détecter les maladies via notre modèle d'IA</li>
        <li>Fournir des recommandations de traitement adaptées</li>
        <li>Afficher les conditions météorologiques de votre zone</li>
        <li>Gérer votre compte utilisateur et votre historique</li>
        <li>Améliorer la précision de notre modèle de détection</li>
    </ul>

    <h2>4. Partage des données</h2>
    <p>Nous ne vendons, ne louons et ne partageons pas vos données personnelles à des tiers à des fins commerciales. Vos données peuvent être partagées uniquement avec :</p>
    <ul>
        <li><strong>OpenWeather API</strong> : Votre localisation est envoyée pour obtenir les données météo (soumis à leur propre politique de confidentialité)</li>
        <li><strong>Services d'hébergement</strong> : Nos serveurs sont hébergés chez Render.com, soumis à leurs standards de sécurité</li>
    </ul>

    <h2>5. Stockage et sécurité</h2>
    <ul>
        <li>Les données sont stockées dans une base de données MongoDB sécurisée avec chiffrement</li>
        <li>Les mots de passe sont hachés et ne sont jamais stockés en clair</li>
        <li>Les communications entre l'application et le serveur sont chiffrées via HTTPS</li>
        <li>Les tokens d'authentification JWT ont une durée de vie limitée</li>
    </ul>

    <h2>6. Permissions de l'application</h2>
    <ul>
        <li><strong>Appareil photo</strong> : Pour prendre des photos de plantes à analyser</li>
        <li><strong>Galerie/Stockage</strong> : Pour sélectionner des images existantes et sauvegarder les rapports</li>
        <li><strong>Localisation</strong> : Pour la géolocalisation des parcelles et les données météo</li>
        <li><strong>Internet</strong> : Pour communiquer avec notre serveur d'analyse IA</li>
        <li><strong>Notifications</strong> : Pour vous informer des résultats d'analyse</li>
    </ul>

    <h2>7. Vos droits</h2>
    <p>Conformément au RGPD et aux lois applicables, vous avez le droit de :</p>
    <ul>
        <li>Accéder à vos données personnelles</li>
        <li>Rectifier vos données inexactes</li>
        <li>Supprimer votre compte et vos données</li>
        <li>Retirer votre consentement à tout moment</li>
        <li>Exporter vos données</li>
    </ul>

    <h2>8. Données des enfants</h2>
    <p>DronIA n'est pas destinée aux enfants de moins de 13 ans. Nous ne collectons pas sciemment de données personnelles auprès d'enfants de moins de 13 ans.</p>

    <h2>9. Modifications</h2>
    <p>Nous pouvons mettre à jour cette politique de confidentialité. Toute modification sera publiée sur cette page avec la date de mise à jour.</p>

    <h2>10. Contact</h2>
    <p>Pour toute question concernant cette politique de confidentialité, contactez-nous à :</p>
    <p>📧 Email : <a href="mailto:dronia.app@gmail.com">dronia.app@gmail.com</a></p>
</div>
</body>
</html>
"""


# ============ OPIE Satellite Mock Endpoint ============
from pydantic import BaseModel
from typing import Optional
import random
from datetime import datetime, timedelta

class SatelliteRequest(BaseModel):
    latitude: float
    longitude: float
    startDate: Optional[str] = None
    endDate: Optional[str] = None
    imageType: Optional[str] = "ndvi"

@app.post("/opie-satellite")
async def get_satellite_data(request: SatelliteRequest):
    """Mock OPIE Satellite endpoint for NDVI and satellite imagery data"""
    # Generate mock satellite data
    base_ndvi = 0.45 + random.random() * 0.35  # NDVI between 0.45 and 0.80
    
    return {
        "success": True,
        "message": "Satellite data retrieved successfully",
        "latitude": request.latitude,
        "longitude": request.longitude,
        "images": [
            {
                "date": (datetime.now() - timedelta(days=i*7)).strftime("%Y-%m-%d"),
                "ndvi": round(base_ndvi + random.uniform(-0.1, 0.1), 3),
                "cloudCoverage": round(random.uniform(0, 30), 1),
                "humidity": round(50 + random.uniform(0, 30), 1),
                "temperature": round(18 + random.uniform(0, 12), 1),
                "imageType": request.imageType,
                "healthScore": round(70 + random.uniform(0, 25), 1),
            }
            for i in range(5)
        ],
        "statistics": {
            "meanNdvi": round(base_ndvi, 3),
            "minNdvi": round(base_ndvi - 0.1, 3),
            "maxNdvi": round(base_ndvi + 0.1, 3),
            "vegetationCoverage": round(60 + random.uniform(0, 30), 1),
        }
    }


# Global model variables
model: YOLO = None
model_path: str = None
classification_model = None
classification_model_path: str = None
classification_class_mapping = None
classification_transform = None

# ViT PlantDoc model variables
vit_model = None
vit_classes = None
vit_transform = None

# Pest detection model (YOLO11s)
pest_detection_model: YOLO = None
pest_detection_model_path: str = None


# At the top of your main.py, add this flag
DISABLE_YOLO = True  # Set to True for Render deployment

# In your predict functions, modify the ensure_model_loaded function:
def ensure_model_loaded():
    """Ensure YOLO model is loaded - DISABLED for free tier deployment"""
    if DISABLE_YOLO:
        raise HTTPException(
            status_code=503, 
            detail="YOLOv8 model disabled for free tier deployment. Use /classify/base64 endpoint instead."
        )


def is_healthy_class(name: str) -> bool:
    """Return True when the class represents a healthy leaf/background."""
    if not name:
        return False
    name_lower = name.lower()
    return name == "Aucune" or "healthy" in name_lower or name_lower.endswith("sain") or name_lower.endswith("saine")


# Comprehensive mapping of all 38 PlantVillage classes to French disease names
DISEASE_NAME_MAP = {
    # Apple diseases
    "Apple___Apple_scab": "Tavelure du pommier",
    "Apple___Black_rot": "Pourriture noire (Pomme)",
    "Apple___Cedar_apple_rust": "Rouille du cèdre",
    "Apple___healthy": "Aucune",
    
    # Blueberry
    "Blueberry___healthy": "Aucune",
    
    # Cherry diseases
    "Cherry_(including_sour)___Powdery_mildew": "Oïdium (Cerise)",
    "Cherry_(including_sour)___healthy": "Aucune",
    
    # Corn diseases
    "Corn_(maize)___Cercospora_leaf_spot_Gray_leaf_spot": "Tache grise des feuilles (Maïs)",
    "Corn_(maize)___Common_rust": "Rouille commune (Maïs)",
    "Corn_(maize)___Northern_Leaf_Blight": "Brûlure septentrionale (Maïs)",
    "Corn_(maize)___healthy": "Aucune",
    
    # Grape diseases
    "Grape___Black_rot": "Pourriture noire (Raisin)",
    "Grape___Esca_(Black_Measles)": "Esca",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "Brûlure des feuilles (Raisin)",
    "Grape___healthy": "Aucune",
    
    # Orange diseases
    "Orange___Haunglongbing_(Citrus_greening)": "Maladie du verdissement (Agrumes)",
    
    # Peach diseases
    "Peach___Bacterial_spot": "Tache bactérienne (Pêche)",
    "Peach___healthy": "Aucune",
    
    # Pepper diseases
    "Pepper,_bell___Bacterial_spot": "Tache bactérienne (Poivron)",
    "Pepper,_bell___healthy": "Aucune",
    "Pepper__bell___Bacterial_spot": "Tache bactérienne (Poivron)",
    "Pepper__bell___healthy": "Aucune",
    
    # Potato diseases
    "Potato___Early_blight": "Alternariose (Pomme de terre)",
    "Potato___Late_blight": "Mildiou (Pomme de terre)",
    "Potato___healthy": "Aucune",
    
    # Raspberry
    "Raspberry___healthy": "Aucune",
    
    # Soybean
    "Soybean___healthy": "Aucune",
    
    # Squash diseases
    "Squash___Powdery_mildew": "Oïdium (Courge)",
    
    # Strawberry diseases
    "Strawberry___Leaf_scorch": "Brûlure des feuilles (Fraise)",
    "Strawberry___healthy": "Aucune",
    
    # Tomato diseases
    "Tomato___Bacterial_spot": "Tache bactérienne (Tomate)",
    "Tomato___Early_blight": "Alternariose (Tomate)",
    "Tomato___Late_blight": "Mildiou (Tomate)",
    "Tomato___Leaf_Mold": "Moisissure des feuilles (Tomate)",
    "Tomato___Septoria_leaf_spot": "Septoriose (Tomate)",
    "Tomato___Spider_mites_Two-spotted_spider_mite": "Acariens (Tomate)",
    "Tomato___Target_Spot": "Taches ciblées (Tomate)",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "Virus de l'enroulement (Tomate)",
    "Tomato___Tomato_mosaic_virus": "Virus de la mosaïque (Tomate)",
    "Tomato___healthy": "Aucune",
    
    # Alternative formats (different naming conventions)
    "Tomato_Bacterial_spot": "Tache bactérienne (Tomate)",
    "Tomato_Early_blight": "Alternariose (Tomate)",
    "Tomato_Late_blight": "Mildiou (Tomate)",
    "Tomato_Leaf_Mold": "Moisissure des feuilles (Tomate)",
    "Tomato_Septoria_leaf_spot": "Septoriose (Tomate)",
    "Tomato_Spider_mites_Two_spotted_spider_mite": "Acariens (Tomate)",
    "Tomato_Spider_mites_Two-spotted_spider_mite": "Acariens (Tomate)",
    "Tomato__Target_Spot": "Taches ciblées (Tomate)",
    "Tomato__Tomato_YellowLeaf__Curl_Virus": "Virus de l'enroulement (Tomate)",
    "Tomato__Tomato_mosaic_virus": "Virus de la mosaïque (Tomate)",
    "Tomato_healthy": "Aucune",
}


# Disease treatment recommendations
DISEASE_RECOMMENDATIONS = {
    "Apple___Apple_scab": {
        "treatment": "Appliquer des fongicides à base de cuivre au printemps. Éliminer les feuilles infectées.",
        "prevention": "Planter des variétés résistantes, maintenir une bonne circulation d'air."
    },
    "Apple___Black_rot": {
        "treatment": "Tailler les branches infectées, appliquer des fongicides.",
        "prevention": "Éliminer les fruits momifiés, éviter les blessures sur l'arbre."
    },
    "Apple___Cedar_apple_rust": {
        "treatment": "Appliquer des fongicides préventifs au printemps.",
        "prevention": "Éliminer les genévriers à proximité, utiliser des variétés résistantes."
    },
    "Cherry_(including_sour)___Powdery_mildew": {
        "treatment": "Fongicides à base de soufre ou bicarbonate de potassium.",
        "prevention": "Bonne circulation d'air, éviter l'arrosage sur les feuilles."
    },
    "Corn_(maize)___Cercospora_leaf_spot_Gray_leaf_spot": {
        "treatment": "Appliquer des fongicides foliaires.",
        "prevention": "Rotation des cultures, éliminer les résidus de récolte."
    },
    "Corn_(maize)___Common_rust": {
        "treatment": "Appliquer des fongicides si l'infection est sévère.",
        "prevention": "Planter des hybrides résistants, semis précoce."
    },
    "Corn_(maize)___Northern_Leaf_Blight": {
        "treatment": "Fongicides foliaires en cas d'infection précoce.",
        "prevention": "Rotation des cultures, hybrides résistants."
    },
    "Grape___Black_rot": {
        "treatment": "Fongicides à base de cuivre ou de mancozèbe.",
        "prevention": "Taille pour améliorer la circulation d'air, éliminer les baies infectées."
    },
    "Grape___Esca_(Black_Measles)": {
        "treatment": "Pas de traitement curatif efficace. Recépage possible.",
        "prevention": "Éviter les blessures, protection des plaies de taille."
    },
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": {
        "treatment": "Fongicides foliaires.",
        "prevention": "Bonne gestion du feuillage, éviter l'humidité excessive."
    },
    "Orange___Haunglongbing_(Citrus_greening)": {
        "treatment": "Pas de traitement curatif. Élimination des arbres infectés recommandée.",
        "prevention": "Contrôle des psylles, plantation de plants certifiés."
    },
    "Peach___Bacterial_spot": {
        "treatment": "Traitements à base de cuivre.",
        "prevention": "Variétés résistantes, éviter l'irrigation par aspersion."
    },
    "Pepper,_bell___Bacterial_spot": {
        "treatment": "Traitements à base de cuivre.",
        "prevention": "Semences certifiées, rotation des cultures."
    },
    "Potato___Early_blight": {
        "treatment": "Fongicides préventifs et curatifs.",
        "prevention": "Rotation des cultures, éliminer les débris végétaux."
    },
    "Potato___Late_blight": {
        "treatment": "Fongicides systémiques et de contact.",
        "prevention": "Plants certifiés, éviter l'humidité excessive, variétés résistantes."
    },
    "Squash___Powdery_mildew": {
        "treatment": "Fongicides à base de soufre ou bicarbonate de potassium.",
        "prevention": "Bonne circulation d'air, éviter l'arrosage sur les feuilles."
    },
    "Strawberry___Leaf_scorch": {
        "treatment": "Fongicides foliaires.",
        "prevention": "Plants sains, espacement adéquat, éviter l'humidité."
    },
    "Tomato___Bacterial_spot": {
        "treatment": "Traitements à base de cuivre.",
        "prevention": "Semences certifiées, rotation des cultures."
    },
    "Tomato___Early_blight": {
        "treatment": "Fongicides préventifs.",
        "prevention": "Rotation des cultures, éliminer les feuilles basses."
    },
    "Tomato___Late_blight": {
        "treatment": "Fongicides systémiques.",
        "prevention": "Éviter l'humidité, plants sains, variétés résistantes."
    },
    "Tomato___Leaf_Mold": {
        "treatment": "Fongicides foliaires.",
        "prevention": "Bonne ventilation, réduire l'humidité."
    },
    "Tomato___Septoria_leaf_spot": {
        "treatment": "Fongicides à base de cuivre.",
        "prevention": "Rotation, éliminer les débris, éviter l'arrosage sur les feuilles."
    },
    "Tomato___Spider_mites_Two-spotted_spider_mite": {
        "treatment": "Acaricides, huile de neem, savon insecticide.",
        "prevention": "Maintenir l'humidité, éliminer les mauvaises herbes."
    },
    "Tomato___Target_Spot": {
        "treatment": "Fongicides foliaires.",
        "prevention": "Rotation, espacement des plants, éviter l'humidité."
    },
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": {
        "treatment": "Pas de traitement curatif. Éliminer les plants infectés.",
        "prevention": "Contrôle des aleurodes, filets anti-insectes, variétés résistantes."
    },
    "Tomato___Tomato_mosaic_virus": {
        "treatment": "Pas de traitement curatif. Éliminer les plants infectés.",
        "prevention": "Hygiène des outils, lavage des mains, semences certifiées."
    },
}


def get_disease_french_name(class_name: str) -> str:
    """Get French name for a disease class"""
    return DISEASE_NAME_MAP.get(class_name, class_name.replace("_", " "))


def get_disease_recommendations(class_name: str) -> dict:
    """Get treatment and prevention recommendations for a disease"""
    # Try exact match first
    if class_name in DISEASE_RECOMMENDATIONS:
        return DISEASE_RECOMMENDATIONS[class_name]
    
    # Try alternative formats
    for key, value in DISEASE_RECOMMENDATIONS.items():
        if key.lower() == class_name.lower() or key.replace(",_", "__") == class_name:
            return value
    
    return {
        "treatment": "Consulter un expert agricole pour un diagnostic précis.",
        "prevention": "Maintenir une bonne hygiène des cultures et surveiller régulièrement les plants."
    }


def build_affected_zones(predictions, image_width: int, image_height: int):
    """
    Convert YOLO predictions to percentage-based zones usable by the frontend overlay.
    Uses normalized boxes when available to avoid scaling mistakes and includes
    both center-based and corner-based coordinates so the UI can render squares.
    """
    zones = []

    def to_zone(pred):
        bbox = pred.get("bbox", {})
        bbox_norm = pred.get("bbox_normalized")

        # Prefer normalized coordinates from YOLO (center x/y, width/height in 0-1 range)
        if bbox_norm:
            cx_pct = bbox_norm["cx"] * 100
            cy_pct = bbox_norm["cy"] * 100
            width_pct = bbox_norm["w"] * 100
            height_pct = bbox_norm["h"] * 100
            x1_pct = (bbox_norm["cx"] - bbox_norm["w"] / 2) * 100
            y1_pct = (bbox_norm["cy"] - bbox_norm["h"] / 2) * 100
            x2_pct = (bbox_norm["cx"] + bbox_norm["w"] / 2) * 100
            y2_pct = (bbox_norm["cy"] + bbox_norm["h"] / 2) * 100
        else:
            x1, y1, x2, y2 = (
                bbox.get("x1", 0.0),
                bbox.get("y1", 0.0),
                bbox.get("x2", 0.0),
                bbox.get("y2", 0.0),
            )
            width_px = max(0.0, x2 - x1)
            height_px = max(0.0, y2 - y1)
            width_pct = (width_px / max(1, image_width)) * 100
            height_pct = (height_px / max(1, image_height)) * 100
            cx_pct = ((x1 + x2) / 2 / max(1, image_width)) * 100
            cy_pct = ((y1 + y2) / 2 / max(1, image_height)) * 100
            x1_pct = (x1 / max(1, image_width)) * 100
            y1_pct = (y1 / max(1, image_height)) * 100
            x2_pct = (x2 / max(1, image_width)) * 100
            y2_pct = (y2 / max(1, image_height)) * 100

        return {
            "x": round(max(0.0, min(100.0, cx_pct)), 2),
            "y": round(max(0.0, min(100.0, cy_pct)), 2),
            "width": round(max(0.0, min(100.0, width_pct)), 2),
            "height": round(max(0.0, min(100.0, height_pct)), 2),
            "radius": round(max(width_pct, height_pct) / 2, 2),
            "x1Pct": round(max(0.0, min(100.0, x1_pct)), 2),
            "y1Pct": round(max(0.0, min(100.0, y1_pct)), 2),
            "x2Pct": round(max(0.0, min(100.0, x2_pct)), 2),
            "y2Pct": round(max(0.0, min(100.0, y2_pct)), 2),
            "className": pred["class_name"],
            "confidence": round(pred["confidence"] * 100, 2)
        }

    diseased_predictions = [
        p for p in predictions if not is_healthy_class(p["class_name"])
    ]

    for pred in diseased_predictions:
        zones.append(to_zone(pred))

    # Fallback: if no diseased zones but we still have predictions, surface the best one
    if not zones and predictions:
        zones.append(to_zone(predictions[0]))

    return zones


def load_model(path: str = None):
    """
    Load YOLOv8 model
    
    Args:
        path: Path to model file (.pt). If None, loads default model.
    """
    global model, model_path
    
    if path is None:
        # Try to find the latest model in models directory
        models_dir = Path(__file__).parent.parent / "models"
        model_files = list(models_dir.glob("*.pt"))
        
        if not model_files:
            logger.warning("No model files found. Using default yolov8n.pt")
            path = "yolov8n.pt"
        else:
            # Use the most recently modified model
            path = max(model_files, key=lambda p: p.stat().st_mtime)
            logger.info(f"Using model: {path}")
    
    try:
        model = YOLO(str(path))
        model_path = str(path)
        logger.info(f"✅ Model loaded successfully: {model_path}")
    except Exception as e:
        logger.error(f"❌ Failed to load model: {str(e)}")
        raise

def load_classification_model(path: str = None):
    """
    Load EfficientNet classification model (memory optimized)
    
    Args:
        path: Path to model file (.pth). If None, tries to find default model.
    """
    global classification_model, classification_model_path, classification_class_mapping, classification_transform
    
    # Clear any existing model from memory first
    if classification_model is not None:
        del classification_model
        gc.collect()
        torch.cuda.empty_cache() if torch.cuda.is_available() else None
    
    if path is None:
        # First, check config.yaml for a specific model path
        config_path = Path(__file__).parent.parent / "config.yaml"
        config_model_path = None
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    config = yaml.safe_load(f)
                    if config and 'efficientnet' in config and 'model_path' in config['efficientnet']:
                        config_model_path = config['efficientnet']['model_path']
                        logger.info(f"📋 Found model path in config: {config_model_path}")
            except Exception as e:
                logger.warning(f"⚠️  Could not read config.yaml: {str(e)}")
        
        # If config specifies a model, try to use it
        if config_model_path:
            models_dir = Path(__file__).parent.parent / "models"
            config_full_path = models_dir / config_model_path
            if config_full_path.exists():
                path = config_full_path
                logger.info(f"✅ Using configured model: {config_model_path}")
            else:
                logger.warning(f"⚠️  Configured model not found: {config_full_path}, falling back to auto-selection")
        
        # If no config path or config path doesn't exist, try to find EfficientNet model in models directory
        if path is None:
            models_dir = Path(__file__).parent.parent / "models"
            model_files = list(models_dir.glob("efficientnet_*.pth"))
            
            if not model_files:
                logger.warning("No EfficientNet model found. Classification will be disabled.")
                return
            else:
                # Prioritize "best" model (highest validation accuracy)
                best_models = [f for f in model_files if "best" in f.name.lower()]
                if best_models:
                    # Load all best models and pick the one with highest val_acc
                    best_path = None
                    best_val_acc = 0.0
                    for model_file in best_models:
                        try:
                            checkpoint = torch.load(str(model_file), map_location='cpu')
                            val_acc = checkpoint.get('val_acc', 0.0)
                            if val_acc > best_val_acc:
                                best_val_acc = val_acc
                                best_path = model_file
                        except:
                            continue
                    
                    if best_path:
                        path = best_path
                        logger.info(f"✅ Using best EfficientNet model: {path.name} (val_acc: {best_val_acc:.2f}%)")
                    else:
                        # Fallback to most recent best model
                        path = max(best_models, key=lambda p: p.stat().st_mtime)
                        logger.info(f"✅ Using EfficientNet model: {path.name}")
                else:
                    # Fallback to most recently modified model
                    path = max(model_files, key=lambda p: p.stat().st_mtime)
                    logger.warning(f"⚠️  No 'best' model found, using most recent: {path.name}")
    
    try:
        # Load checkpoint with memory mapping to reduce RAM usage
        checkpoint = torch.load(str(path), map_location='cpu', weights_only=False)
        
        # Get model info BEFORE deleting checkpoint
        num_classes = checkpoint.get('num_classes', 15)
        model_name = checkpoint.get('model_name', 'b0')
        class_mapping = checkpoint.get('class_mapping', {})
        val_acc = checkpoint.get('val_acc', 'N/A')
        train_acc = checkpoint.get('train_acc', 'N/A')
        epoch = checkpoint.get('epoch', 'N/A')
        
        # If class_mapping is missing or empty, try to load from YAML file
        if not class_mapping or not class_mapping.get('idx_to_class'):
            logger.warning("⚠️  Class mapping not found in checkpoint, trying to load from YAML...")
            # Try to find class_mapping.yaml in datasets directory
            datasets_dir = Path(__file__).parent.parent / "datasets"
            yaml_files = list(datasets_dir.rglob("class_mapping.yaml"))
            if yaml_files:
                yaml_file = yaml_files[0]
                logger.info(f"   Loading class mapping from: {yaml_file}")
                with open(yaml_file, 'r') as f:
                    class_mapping = yaml.safe_load(f)
            else:
                logger.warning("   No class_mapping.yaml found, class names may be incorrect")
        
        # Normalize class mapping: ensure idx_to_class keys are integers
        if class_mapping and 'idx_to_class' in class_mapping:
            idx_to_class = {}
            for k, v in class_mapping['idx_to_class'].items():
                idx_to_class[int(k)] = v
            class_mapping['idx_to_class'] = idx_to_class
            logger.info(f"   Loaded class mapping with {len(idx_to_class)} classes")
            if len(idx_to_class) > 0:
                logger.info(f"   Sample classes: {list(idx_to_class.values())[:3]}")
        
        # Normalize model_name (checkpoint may have 'efficientnet_b0' or 'b0')
        if model_name.startswith('efficientnet_'):
            model_name = model_name.replace('efficientnet_', '')  # 'efficientnet_b0' -> 'b0'
        elif model_name.startswith('efficientnet-'):
            model_name = model_name.replace('efficientnet-', '')  # 'efficientnet-b0' -> 'b0'
        
        # Create model - use torchvision (model was trained with torchvision)
        from torchvision import models
        if model_name == 'b0':
            classification_model = models.efficientnet_b0(weights=None)
        elif model_name == 'b1':
            classification_model = models.efficientnet_b1(weights=None)
        elif model_name == 'b2':
            classification_model = models.efficientnet_b2(weights=None)
        elif model_name == 'b3':
            classification_model = models.efficientnet_b3(weights=None)
        else:
            classification_model = models.efficientnet_b0(weights=None)
        
        # Replace classifier to match num_classes
        num_features = classification_model.classifier[1].in_features
        classification_model.classifier = torch.nn.Sequential(
            torch.nn.Dropout(p=0.2, inplace=True),
            torch.nn.Linear(num_features, num_classes)
        )
        
        # Load weights with strict checking
        try:
            classification_model.load_state_dict(checkpoint['model_state_dict'], strict=True)
            logger.info("   ✅ Model weights loaded successfully")
        except RuntimeError as e:
            logger.error(f"   ❌ Model architecture mismatch: {str(e)}")
            raise
        
        # CRITICAL: Set model to evaluation mode (prevents dropout and batch norm issues)
        classification_model.eval()
        
        # Memory optimizations: disable gradient computation and set to inference mode
        for param in classification_model.parameters():
            param.requires_grad = False
        torch.set_grad_enabled(False)
        
        # Verify model is in eval mode
        if classification_model.training:
            logger.error("   ❌ ERROR: Model is still in training mode!")
            classification_model.eval()
            if classification_model.training:
                raise RuntimeError("Failed to set model to eval mode")
        else:
            logger.info("   ✅ Model is in eval mode (correct for inference)")
        
        # NOW we can safely delete checkpoint after extracting all needed info
        del checkpoint
        gc.collect()
        
        # Set transform (must match training transform)
        classification_transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])
        
        classification_model_path = str(path)
        classification_class_mapping = class_mapping
        
        # Log model information for verification
        logger.info(f"✅ EfficientNet model loaded successfully: {classification_model_path}")
        logger.info(f"   📊 Model Info:")
        logger.info(f"      - Classes: {num_classes}")
        logger.info(f"      - Validation Accuracy: {val_acc if isinstance(val_acc, (int, float)) else val_acc:.2f}%")
        if isinstance(train_acc, (int, float)):
            logger.info(f"      - Training Accuracy: {train_acc:.2f}%")
            # Check for overfitting: if val_acc is much lower than train_acc
            if isinstance(val_acc, (int, float)) and train_acc - val_acc > 5:
                logger.warning(f"      ⚠️  Potential overfitting detected: train_acc ({train_acc:.2f}%) >> val_acc ({val_acc:.2f}%)")
        logger.info(f"      - Epoch: {epoch}")
        logger.info(f"      - Model: EfficientNet-{model_name}")
        
        # Verify class mapping
        if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
            logger.info(f"      - Class mapping: {len(classification_class_mapping['idx_to_class'])} classes loaded")
        else:
            logger.warning(f"      ⚠️  Class mapping incomplete - predictions may use class indices")
        
    except Exception as e:
        logger.error(f"❌ Failed to load EfficientNet model: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        logger.warning("Classification will be disabled.")
        classification_model = None
        classification_model_path = None

# 1. Remove or modify the ensure_model_loaded() function
def ensure_model_loaded():
    """Ensure YOLO model is loaded - DISABLED to save memory"""
    # Don't raise exception, just skip YOLO
    if DISABLE_YOLO:
        logger.info("⚠️  YOLO is disabled for memory optimization")
        return
    
    global model
    if model is None:
        logger.info("📦 Loading YOLO model (lazy load)...")
        load_model()

def ensure_classification_model_loaded():
    """Ensure EfficientNet model is loaded (lazy loading)"""
    global classification_model
    if classification_model is None:
        logger.info("📦 Loading EfficientNet model (lazy load)...")
        load_classification_model()

@app.on_event("startup")
async def startup_event():
    """Startup: ViT only on Render (EfficientNet runs on VPS)"""
    logger.info("🚀 Starting Dronia API — ViT PlantDoc mode (Render)")
    logger.info("ℹ️  EfficientNet is hosted on VPS — not loaded here")
    logger.info("📦 Pre-loading ViT model...")
    try:
        load_vit_model()
        logger.info("✅ ViT model ready — endpoint: POST /classify/vit")
    except Exception as e:
        logger.error(f"❌ Failed to load ViT: {str(e)}")
    logger.info("⚠️  YOLO disabled | EfficientNet disabled (VPS only)")


# Also update the root endpoint to reflect EfficientNet-only mode:
@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "Dronia API — ViT PlantDoc (Render)",
        "vit_model": "loaded" if vit_model is not None else "not loaded",
        "efficientnet": "hosted on VPS",
        "endpoints": {
            "vit_classification": "/classify/vit",
            "insect_detection": "/analyze/insects",
            "health": "/health",
        },
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "vit_model_loaded": vit_model is not None,
        "vit_classes": vit_classes["num_classes"] if vit_classes else 0,
        "efficientnet": "on VPS — not loaded here",
        "mode": "ViT only",
    }






@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    confidence: float = Form(0.25),
    iou: float = Form(0.45)
):
    """
    Predict plant diseases from uploaded image
    
    Args:
        file: Image file (JPEG, PNG, etc.)
        confidence: Confidence threshold (0.0-1.0)
        iou: IoU threshold for NMS (0.0-1.0)
        
    Returns:
        JSON response with predictions
    """
    ensure_model_loaded()
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Read image
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Run prediction with lower threshold to catch more detections
        # Use minimum of requested confidence or 0.10 to ensure we don't miss diseases
        effective_confidence = min(confidence, 0.10)
        logger.info(f"🔍 Running prediction on image: {file.filename} (conf={effective_confidence:.2f})")
        results = model.predict(
            image,
            conf=effective_confidence,
            iou=iou,
            verbose=False
        )
        
        # Process results
        result = results[0]  # Get first result
        boxes = result.boxes
        
        # Extract predictions
        predictions = []
        for box in boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])
            xyxy = box.xyxy[0].tolist()
            xywhn = box.xywhn[0].tolist()
            
            predictions.append({
                "class": cls,
                "class_name": result.names[cls] if hasattr(result, 'names') else f"class_{cls}",
                "confidence": round(conf, 4),
                "bbox": {
                    "x1": float(xyxy[0]),
                    "y1": float(xyxy[1]),
                    "x2": float(xyxy[2]),
                    "y2": float(xyxy[3])
                },
                "bbox_normalized": {
                    "cx": float(xywhn[0]),
                    "cy": float(xywhn[1]),
                    "w": float(xywhn[2]),
                    "h": float(xywhn[3])
                }
            })
        
        # Sort by confidence
        predictions.sort(key=lambda x: x["confidence"], reverse=True)
        
        # Log top predictions for debugging
        logger.info(f"📊 YOLOv8 predictions ({len(predictions)} total):")
        if len(predictions) == 0:
            logger.warning("⚠️  No detections found! Model might need retraining or confidence threshold too high.")
        for i, pred in enumerate(predictions[:5]):  # Show top 5 for debugging
            is_healthy_pred = is_healthy_class(pred["class_name"])
            logger.info(f"   {i+1}. {pred['class_name']}: {pred['confidence']:.2%} (healthy: {is_healthy_pred})")
        
        # Get top prediction
        top_prediction = predictions[0] if predictions else None
        
        # Prefer a non-healthy class if one exists to avoid false "healthy" when a diseased box has slightly lower confidence
        diseased_predictions = [
            p for p in predictions if not is_healthy_class(p["class_name"])
        ]
        
        if len(diseased_predictions) > 0:
            logger.info(f"   Found {len(diseased_predictions)} disease detection(s) out of {len(predictions)} total")
        else:
            logger.warning(f"   ⚠️  No disease detections found! All {len(predictions)} predictions are healthy classes.")
        
        primary_prediction = diseased_predictions[0] if diseased_predictions else top_prediction

        # Format for frontend
        disease_name = primary_prediction["class_name"] if primary_prediction else "Aucune"
        confidence_pct = int(primary_prediction["confidence"] * 100) if primary_prediction else 0

        # Determine if healthy based on the chosen primary prediction
        is_healthy = is_healthy_class(disease_name)
        logger.info(f"   Primary: '{disease_name}' (confidence: {confidence_pct}%) -> is_healthy: {is_healthy}")
        
        # If we have disease predictions but they're being ignored, warn
        if len(diseased_predictions) > 0 and is_healthy:
            logger.error(f"   ❌ ERROR: Disease detected but marked as healthy! Check is_healthy_class() function.")
        # Note: If the class name indicates healthy, we trust it regardless of confidence.
        # Low confidence just means uncertainty, but the prediction is still "healthy".
        # Only mark as unhealthy if the class name itself indicates disease.
        
        # Determine severity
        severity = "Nulle"
        status = "Sain"
        if primary_prediction and not is_healthy:
            if confidence_pct > 85:
                severity = "Élevée"
                status = "Critique"
            elif confidence_pct > 70:
                severity = "Modérée"
                status = "Critique"
            else:
                severity = "Légère"
                status = "Attention"
        
        # General status (Malade or Saine)
        general_status = "Saine" if is_healthy else "Malade"
        
        # Disease percentage (0 if healthy, confidence if malade)
        disease_percentage = 0 if is_healthy else confidence_pct
        
        # Calculate affected surface from all detections (diseased only)
        # Use union of bounding boxes to avoid double-counting overlapping areas
        image_area = image.width * image.height
        affected_area = 0.0
        
        if diseased_predictions:
            # Calculate total area covered by disease boxes (as percentage)
            # Since bbox_normalized w and h are already normalized (0-1), 
            # we can directly sum the areas and cap at 100%
            total_disease_area = 0.0
            for pred in diseased_predictions:
                bbox_norm = pred.get("bbox_normalized")
                if bbox_norm:
                    # w and h are normalized (0-1), so w * h gives fraction of image
                    box_area = bbox_norm["w"] * bbox_norm["h"]
                    total_disease_area += box_area
                    logger.debug(f"   Disease box: {pred['class_name']} covers {box_area:.2%} of image")
                else:
                    # Fallback to pixel-based calculation
                    bbox = pred.get("bbox", {})
                    box_width = bbox.get("x2", 0) - bbox.get("x1", 0)
                    box_height = bbox.get("y2", 0) - bbox.get("y1", 0)
                    box_area = (box_width * box_height) / image_area if image_area else 0
                    total_disease_area += box_area
            
            # Cap at 100% and convert to percentage
            affected_surface = min(100, max(0, int(total_disease_area * 100)))
            logger.info(f"   Affected surface: {affected_surface}% (from {len(diseased_predictions)} disease detection(s))")
        else:
            affected_surface = 0

        # Generate affected zones from YOLO detections (prioritize non-healthy)
        affected_zones = build_affected_zones(predictions, image.width, image.height)
        
        response = {
            "success": True,
            "disease": disease_name,
            "confidence": confidence_pct,
            "severity": severity,
            "status": status,
            "affectedSurface": affected_surface,
            "affectedZones": affected_zones,
            "generalStatus": general_status,
            "diseasePercentage": disease_percentage,
            "predictions": predictions,
            "source": "yolov8"
        }
        
        logger.info(f"✅ Prediction complete: {len(predictions)} detections")
        return JSONResponse(content=response)
        
    except Exception as e:
        logger.error(f"❌ Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")



@app.post("/predict/base64")
async def predict_base64(
    image: str = Form(...),
    confidence: float = Form(0.25),
    iou: float = Form(0.45)
):
    """YOLO detection endpoint - DISABLED"""
    raise HTTPException(
        status_code=503,
        detail="YOLOv8 detection is disabled. Please use POST /classify/base64 for EfficientNet classification."
    )
    
    # Only try to load YOLO if not disabled
    ensure_model_loaded()
    if model is None:
        raise HTTPException(status_code=503, detail="YOLO model not loaded")
  
    
    try:
        # Decode base64 image
        if image.startswith('data:image'):
            image = image.split(',')[1]
        
        image_bytes = base64.b64decode(image)
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Run prediction with lower threshold to catch more detections
        # Use minimum of requested confidence or 0.10 to ensure we don't miss diseases
        effective_confidence = min(confidence, 0.10)
        logger.info(f"🔍 Running prediction on base64 image (conf={effective_confidence:.2f})")
        results = model.predict(
            image,
            conf=effective_confidence,
            iou=iou,
            verbose=False
        )
        
        # Process results (same as /predict endpoint)
        result = results[0]
        boxes = result.boxes
        
        predictions = []
        for box in boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])
            xyxy = box.xyxy[0].tolist()
            xywhn = box.xywhn[0].tolist()
            
            predictions.append({
                "class": cls,
                "class_name": result.names[cls] if hasattr(result, 'names') else f"class_{cls}",
                "confidence": round(conf, 4),
                "bbox": {
                    "x1": float(xyxy[0]),
                    "y1": float(xyxy[1]),
                    "x2": float(xyxy[2]),
                    "y2": float(xyxy[3])
                },
                "bbox_normalized": {
                    "cx": float(xywhn[0]),
                    "cy": float(xywhn[1]),
                    "w": float(xywhn[2]),
                    "h": float(xywhn[3])
                }
            })
        
        predictions.sort(key=lambda x: x["confidence"], reverse=True)
        
        # Log top predictions for debugging
        logger.info(f"📊 YOLOv8 predictions ({len(predictions)} total):")
        for i, pred in enumerate(predictions[:3]):
            is_healthy_pred = is_healthy_class(pred["class_name"])
            logger.info(f"   {i+1}. {pred['class_name']}: {pred['confidence']:.2%} (healthy: {is_healthy_pred})")
        
        top_prediction = predictions[0] if predictions else None

        # Prefer a non-healthy class if one exists to avoid false "healthy" when a diseased box has slightly lower confidence
        diseased_predictions = [
            p for p in predictions if not is_healthy_class(p["class_name"])
        ]
        primary_prediction = diseased_predictions[0] if diseased_predictions else top_prediction

        # Format for frontend
        disease_name = primary_prediction["class_name"] if primary_prediction else "Aucune"
        confidence_pct = int(primary_prediction["confidence"] * 100) if primary_prediction else 0

        # Determine if healthy based on the chosen primary prediction
        is_healthy = is_healthy_class(disease_name)
        logger.info(f"   Primary: '{disease_name}' (confidence: {confidence_pct}%) -> is_healthy: {is_healthy}")
        # Note: If the class name indicates healthy, we trust it regardless of confidence.
        # Low confidence just means uncertainty, but the prediction is still "healthy".
        # Only mark as unhealthy if the class name itself indicates disease.
        
        # Determine severity
        severity = "Nulle"
        status = "Sain"
        if primary_prediction and not is_healthy:
            if confidence_pct > 85:
                severity = "Élevée"
                status = "Critique"
            elif confidence_pct > 70:
                severity = "Modérée"
                status = "Critique"
            else:
                severity = "Légère"
                status = "Attention"
        
        # General status (Malade or Saine)
        general_status = "Saine" if is_healthy else "Malade"
        
        # Disease percentage (0 if healthy, confidence if malade)
        disease_percentage = 0 if is_healthy else confidence_pct
        
        # Calculate affected surface from all detections (diseased only)
        # Use union of bounding boxes to avoid double-counting overlapping areas
        image_area = image.width * image.height
        affected_area = 0.0
        
        if diseased_predictions:
            # Calculate total area covered by disease boxes (as percentage)
            # Since bbox_normalized w and h are already normalized (0-1), 
            # we can directly sum the areas and cap at 100%
            total_disease_area = 0.0
            for pred in diseased_predictions:
                bbox_norm = pred.get("bbox_normalized")
                if bbox_norm:
                    # w and h are normalized (0-1), so w * h gives fraction of image
                    box_area = bbox_norm["w"] * bbox_norm["h"]
                    total_disease_area += box_area
                    logger.debug(f"   Disease box: {pred['class_name']} covers {box_area:.2%} of image")
                else:
                    # Fallback to pixel-based calculation
                    bbox = pred.get("bbox", {})
                    box_width = bbox.get("x2", 0) - bbox.get("x1", 0)
                    box_height = bbox.get("y2", 0) - bbox.get("y1", 0)
                    box_area = (box_width * box_height) / image_area if image_area else 0
                    total_disease_area += box_area
            
            # Cap at 100% and convert to percentage
            affected_surface = min(100, max(0, int(total_disease_area * 100)))
            logger.info(f"   Affected surface: {affected_surface}% (from {len(diseased_predictions)} disease detection(s))")
        else:
            affected_surface = 0

        # Generate affected zones from YOLO detections (prioritize non-healthy)
        affected_zones = build_affected_zones(predictions, image.width, image.height)
        
        response = {
            "success": True,
            "disease": disease_name,
            "confidence": confidence_pct,
            "severity": severity,
            "status": status,
            "affectedSurface": affected_surface,
            "affectedZones": affected_zones,
            "generalStatus": general_status,
            "diseasePercentage": disease_percentage,
            "predictions": predictions,
            "source": "yolov8"
        }
        
        logger.info(f"✅ Prediction complete: {disease_name} ({confidence_pct}%)")
        return JSONResponse(content=response)
        
    except Exception as e:
        logger.error(f"❌ Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


# 3. Fix the classify_base64 endpoint - remove ensure_model_loaded() call
@app.post("/classify/base64")
async def classify_base64(
    image: str = Form(...),
    zones: str = Form(None)
):
    """
    Classify plant diseases using EfficientNet on detected zones or full image
    """
    # Load classification model if not already loaded (don't check YOLO)
    if classification_model is None:
        logger.info("📦 Loading EfficientNet model (lazy load)...")
        load_classification_model()
    
    # Verify model is loaded and ready
    if classification_model is None:
        logger.error("❌ EfficientNet model is None - cannot classify")
        raise HTTPException(
            status_code=503, 
            detail="EfficientNet classification model not loaded. Please check server logs for model loading errors."
        )
    
    # CRITICAL: Ensure model is in eval mode (prevents inconsistent predictions)
    if classification_model.training:
        logger.warning("⚠️  Model was in training mode! Setting to eval mode...")
        classification_model.eval()
    
    logger.info(f"🔍 Starting EfficientNet classification (model: {Path(classification_model_path).name})")
    
    try:
        import json
        
        # Decode base64 image
        if image.startswith('data:image'):
            image = image.split(',')[1]
        
        image_bytes = base64.b64decode(image)
        pil_image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed
        if pil_image.mode != 'RGB':
            pil_image = pil_image.convert('RGB')
        
        image_width, image_height = pil_image.size
        logger.info(f"   Image size: {image_width}x{image_height}")
        
        # Parse zones if provided
        zone_list = []
        if zones:
            try:
                zone_list = json.loads(zones)
            except:
                pass
        
        # Classify each zone or full image
        classifications = []
        
        if zone_list and len(zone_list) > 0:
            # Classify each detected zone
            logger.info(f"🔍 Classifying {len(zone_list)} detected zones")
            for i, zone in enumerate(zone_list):
                # Extract zone coordinates
                x1_pct = zone.get('x1Pct', zone.get('x', 0) - zone.get('width', 0) / 2)
                y1_pct = zone.get('y1Pct', zone.get('y', 0) - zone.get('height', 0) / 2)
                x2_pct = zone.get('x2Pct', zone.get('x', 0) + zone.get('width', 0) / 2)
                y2_pct = zone.get('y2Pct', zone.get('y', 0) + zone.get('height', 0) / 2)
                
                # Convert percentages to pixels
                x1 = int(x1_pct / 100 * image_width)
                y1 = int(y1_pct / 100 * image_height)
                x2 = int(x2_pct / 100 * image_width)
                y2 = int(y2_pct / 100 * image_height)
                
                # Crop zone with padding
                padding = 10
                x1 = max(0, x1 - padding)
                y1 = max(0, y1 - padding)
                x2 = min(image_width, x2 + padding)
                y2 = min(image_height, y2 + padding)
                
                crop = pil_image.crop((x1, y1, x2, y2))
                
                # Classify crop
                crop_tensor = classification_transform(crop).unsqueeze(0)
                
                with torch.no_grad():
                    outputs = classification_model(crop_tensor)
                    probs = torch.nn.functional.softmax(outputs[0], dim=0)
                    top_prob, top_idx = torch.max(probs, 0)
                    
                    # Get class name
                    if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
                        idx_to_class = classification_class_mapping['idx_to_class']
                        class_name = idx_to_class.get(int(top_idx), f"class_{int(top_idx)}")
                        logger.info(f"   Zone {i}: predicted class_idx={int(top_idx)}, class_name='{class_name}', confidence={float(top_prob):.2%}")
                    else:
                        class_name = f"class_{int(top_idx)}"
                        logger.warning(f"   Zone {i}: No class mapping available, using class_{int(top_idx)}")
                    
                    classifications.append({
                        "zone_index": i,
                        "class_name": class_name,
                        "confidence": float(top_prob),
                        "bbox": {
                            "x1": x1,
                            "y1": y1,
                            "x2": x2,
                            "y2": y2
                        }
                    })
        else:
            # No zones provided - classify full image with EfficientNet
            logger.info("🔍 No zones provided - classifying full image with EfficientNet")
            
            # Ensure model is in eval mode
            classification_model.eval()
            
            # Apply transform
            image_tensor = classification_transform(pil_image).unsqueeze(0)
            
            # Verify tensor shape
            if image_tensor.shape != (1, 3, 224, 224):
                logger.warning(f"   ⚠️  Unexpected tensor shape: {image_tensor.shape}, expected (1, 3, 224, 224)")
            
            with torch.no_grad():
                outputs = classification_model(image_tensor)
                
                # Verify output shape matches number of classes
                if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
                    expected_classes = len(classification_class_mapping['idx_to_class'])
                else:
                    expected_classes = outputs.shape[1]  # Use actual output size if mapping unavailable
                
                if outputs.shape[1] != expected_classes:
                    logger.warning(f"   ⚠️  Output shape mismatch: {outputs.shape[1]} classes vs expected {expected_classes}")
                
                probs = torch.nn.functional.softmax(outputs[0], dim=0)
                top_prob, top_idx = torch.max(probs, 0)
                
                # Get top 3 predictions for debugging (helps detect overfitting)
                top3_probs, top3_indices = torch.topk(probs, min(3, len(probs)))
                logger.info(f"   Top 3 predictions:")
                for i, (prob, idx) in enumerate(zip(top3_probs, top3_indices)):
                    if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
                        idx_to_class = classification_class_mapping['idx_to_class']
                        class_name = idx_to_class.get(int(idx), f"class_{int(idx)}")
                    else:
                        class_name = f"class_{int(idx)}"
                    logger.info(f"      {i+1}. {class_name}: {float(prob):.2%}")
                
                # Get class name for primary prediction
                if classification_class_mapping and 'idx_to_class' in classification_class_mapping:
                    idx_to_class = classification_class_mapping['idx_to_class']
                    class_name = idx_to_class.get(int(top_idx), f"class_{int(top_idx)}")
                    logger.info(f"   ✅ Primary: class_idx={int(top_idx)}, class_name='{class_name}', confidence={float(top_prob):.2%}")
                else:
                    class_name = f"class_{int(top_idx)}"
                    logger.warning(f"   ⚠️  No class mapping available, using class_{int(top_idx)}")
                
                # Check for suspiciously high confidence (potential overfitting indicator)
                if float(top_prob) > 0.999:
                    logger.warning(f"   ⚠️  Very high confidence ({float(top_prob):.2%}) - may indicate overfitting")
                
                # CRITICAL: Check for low confidence - indicates image may not match any training class
                # If confidence is too low, the image likely doesn't belong to the dataset
                CONFIDENCE_THRESHOLD = 0.50  # 50% - below this, we're not confident
                is_low_confidence = float(top_prob) < CONFIDENCE_THRESHOLD
                
                if is_low_confidence:
                    logger.warning(f"   ⚠️  LOW CONFIDENCE ({float(top_prob):.2%}) - Image may not match any training class!")
                    logger.warning(f"   ⚠️  The model was trained on 15 specific classes. This image might be:")
                    logger.warning(f"       - A different disease not in the training set")
                    logger.warning(f"       - A different plant species")
                    logger.warning(f"       - An image that doesn't match the dataset")
                
                classifications.append({
                    "zone_index": 0,
                    "class_name": class_name,
                    "confidence": float(top_prob),
                    "bbox": None,
                    "is_low_confidence": is_low_confidence  # Flag for frontend
                })
        
        # Aggregate results
        if not classifications:
            raise ValueError("No classifications generated")
        
        # Get primary classification (highest confidence)
        primary = max(classifications, key=lambda x: x['confidence'])
        disease_name = primary['class_name']
        confidence_pct = int(primary['confidence'] * 100)
        is_low_confidence = primary.get('is_low_confidence', False)
        
        # Log all top predictions for debugging
        logger.info(f"📊 EfficientNet predictions:")
        for i, cls in enumerate(sorted(classifications, key=lambda x: x['confidence'], reverse=True)[:3]):
            logger.info(f"   {i+1}. {cls['class_name']}: {cls['confidence']:.2%}")
        
        # Determine if healthy
        is_healthy = is_healthy_class(disease_name)
        logger.info(f"   Primary: '{disease_name}' (confidence: {confidence_pct}%) -> is_healthy: {is_healthy}")
        
        # IMPORTANT: If confidence is too low, warn that image may not be in dataset
        if is_low_confidence:
            logger.warning("=" * 60)
            logger.warning("⚠️  WARNING: Low confidence prediction detected!")
            logger.warning("   The model was trained on a specific dataset with 15 classes:")
            logger.warning("   - Pepper, Potato, and Tomato diseases only")
            logger.warning("   - If your image shows a different plant or disease,")
            logger.warning("     the model will still predict one of the 15 classes,")
            logger.warning("     but with low confidence (this is expected behavior).")
            logger.warning("=" * 60)
        
        # Analyze image visually to detect disease symptoms (yellow, brown, black areas)
        logger.info("🔬 Analyzing image for visual disease symptoms...")
        visual_analysis = analyze_leaf_health(pil_image)
        visual_affected_surface = visual_analysis['affected_surface']
        visual_severity = visual_analysis['severity']
        symptom_count = visual_analysis['symptom_count']
        
        logger.info(f"   Visual analysis: {visual_affected_surface}% affected surface, {visual_severity} severity, {symptom_count} symptom areas")
        
        # Use visual analysis for severity and affected surface if disease detected
        # Only override if model detected disease (not healthy)
        if not is_healthy:
            # Use visual analysis for severity (more reliable than model confidence)
            severity = visual_severity if visual_affected_surface > 0 else "Légère"
            
            # Determine status based on visual severity
            if severity == "Élevée":
                status = "Critique"
            elif severity == "Modérée":
                status = "Critique"
            elif severity == "Légère":
                status = "Attention"
            else:
                status = "Sain"
            
            # Use visual affected surface if available, otherwise use confidence as fallback
            affected_surface = int(visual_affected_surface) if visual_affected_surface > 0 else min(50, confidence_pct)
        else:
            # Healthy plant
            severity = "Nulle"
            status = "Sain"
            affected_surface = 0
            visual_affected_surface = 0
        
        # General status
        general_status = "Saine" if is_healthy else "Malade"
        disease_percentage = 0 if is_healthy else confidence_pct
        
        # Get French name and recommendations
        disease_french = get_disease_french_name(disease_name)
        recommendations = get_disease_recommendations(disease_name) if not is_healthy else {}
        
        # Extract plant type from class name (e.g., "Tomato" from "Tomato___Late_blight")
        plant_type = disease_name.split("___")[0].split("_")[0] if "___" in disease_name or "_" in disease_name else "Unknown"
        
        response = {
            "success": True,
            "disease": disease_french,  # French name for display
            "diseaseClass": disease_name,  # Original class name for reference
            "isHealthy": is_healthy,  # Boolean flag for healthy/diseased
            "confidence": confidence_pct,
            "severity": severity,
            "status": status,
            "generalStatus": general_status,
            "diseasePercentage": disease_percentage,
            "affectedSurface": affected_surface,
            "symptomCount": symptom_count,
            "plantType": plant_type,
            "recommendations": recommendations,
            "visualAnalysis": {
                "affectedSurface": visual_affected_surface,
                "severity": visual_severity,
                "symptomCount": symptom_count
            },
            "classifications": classifications,
            "source": "efficientnet",
            "isLowConfidence": is_low_confidence,  # Flag for frontend to show warning
            "warning": "Image may not match training dataset. Model trained on 38 PlantVillage disease classes." if is_low_confidence else None
        }
        
        logger.info(f"✅ Classification complete: {disease_french} ({confidence_pct}%)")
        return JSONResponse(content=response)
        
    except Exception as e:
        logger.error(f"❌ Classification error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Classification failed: {str(e)}")


@app.post("/model/reload")
async def reload_model(path: str = Form(None)):
    """
    Reload model from file
    
    Args:
        path: Path to model file (optional, uses default if not provided)
    """
    try:
        load_model(path)
        return {
            "success": True,
            "message": "Model reloaded successfully",
            "model_path": model_path
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reload model: {str(e)}")


# ==================== PEST DETECTION (YOLO11s) ====================

def load_pest_detection_model():
    """
    Load YOLO11s pest detection model
    Searches multiple directories: backend/models, root models folder
    """
    global pest_detection_model, pest_detection_model_path
    
    # Clear any existing model from memory
    if pest_detection_model is not None:
        del pest_detection_model
        gc.collect()
    
    # Search multiple possible locations for the pest detection model
    model_name = "yolo11s_pest_detection.pt"
    possible_paths = [
        Path(__file__).parent.parent / "models" / model_name,  # backend/models/
        Path(__file__).parent.parent.parent / "models" / model_name,  # dronia/models/
        Path(__file__).parent / "models" / model_name,  # api/models/
    ]
    
    model_path_pest = None
    for path in possible_paths:
        if path.exists():
            model_path_pest = path
            logger.info(f"Found pest detection model at: {path}")
            break
    
    if model_path_pest is None:
        logger.error(f"❌ Pest detection model not found: {model_name}")
        logger.error(f"Searched paths: {[str(p) for p in possible_paths]}")
        raise FileNotFoundError(f"Pest detection model not found: {model_name}")
    
    try:
        pest_detection_model = YOLO(str(model_path_pest))
        pest_detection_model_path = str(model_path_pest)
        logger.info(f"✅ Pest detection model loaded successfully: {pest_detection_model_path}")
    except Exception as e:
        logger.error(f"❌ Failed to load pest detection model: {str(e)}")
        raise


# IP102 Dataset class names (102 insect pest species)
IP102_CLASS_NAMES = {
    0: "Riz - Cicadelle brune",
    1: "Riz - Cicadelle verte petite",
    2: "Riz - Cicadelle verte grande",
    3: "Riz - Charançon de la tige",
    4: "Riz - Noctuelle du riz",
    5: "Riz - Pyrale du riz",
    6: "Riz - Thrips",
    7: "Riz - Punaise verte",
    8: "Maïs - Pyrale du maïs asiatique",
    9: "Maïs - Ver de l'épi",
    10: "Maïs - Légionnaire d'automne",
    11: "Maïs - Chenille des gaules",
    12: "Maïs - Charançon du maïs",
    13: "Blé - Puceron du blé",
    14: "Blé - Mouche à scie du blé",
    15: "Blé - Cécidomyie du blé",
    16: "Blé - Charançon du blé",
    17: "Blé - Punaise du blé",
    18: "Blé - Thrips du blé",
    19: "Coton - Puceron du coton",
    20: "Coton - Ver de la capsule",
    21: "Coton - Ver rose du coton",
    22: "Coton - Charançon du bourgeon",
    23: "Coton - Aleurode du coton",
    24: "Soja - Larve de la cicadelle",
    25: "Soja - Scarabée du soja",
    26: "Soja - Punaise du soja",
    27: "Soja - Noctuelle du soja",
    28: "Soja - Araignée rouge",
    29: "Légumes - Teigne des crucifères",
    30: "Légumes - Piéride du chou",
    31: "Légumes - Noctuelle du chou",
    32: "Légumes - Puceron du chou",
    33: "Légumes - Altise du chou",
    34: "Légumes - Mouche du chou",
    35: "Agrumes - Cochenille farineuse",
    36: "Agrumes - Cochenille virgule",
    37: "Agrumes - Mineuse des agrumes",
    38: "Agrumes - Psylle asiatique",
    39: "Agrumes - Acarien rouge",
    40: "Agrumes - Aleurode des agrumes",
    41: "Fruits - Drosophile à ailes tachetées",
    42: "Fruits - Carpocapse des pommes",
    43: "Fruits - Mouche méditerranéenne",
    44: "Fruits - Mineuse des feuilles",
    45: "Fruits - Puceron vert du pommier",
    46: "Fruits - Tordeuse orientale",
    47: "Thé - Cicadelle du thé",
    48: "Thé - Araignée du thé",
    49: "Thé - Tordeuse du thé",
    50: "Thé - Cochenille du thé",
    51: "Tabac - Ver du bourgeon du tabac",
    52: "Tabac - Puceron du tabac",
    53: "Tabac - Aleurode du tabac",
    54: "Tabac - Thrips du tabac",
    55: "Canne à sucre - Pyrale de la canne",
    56: "Canne à sucre - Termite de la canne",
    57: "Canne à sucre - Cicadelle de la canne",
    58: "Canne à sucre - Puceron de la canne",
    59: "Vigne - Cicadelle de la vigne",
    60: "Vigne - Tordeuse de la grappe",
    61: "Vigne - Cochenille farineuse de la vigne",
    62: "Vigne - Phylloxéra",
    63: "Vigne - Acarien rouge de la vigne",
    64: "Tomate - Mouche blanche",
    65: "Tomate - Mineuse de la tomate",
    66: "Tomate - Teigne de la tomate",
    67: "Tomate - Noctuelle de la tomate",
    68: "Tomate - Acarien de la tomate",
    69: "Pomme de terre - Doryphore",
    70: "Pomme de terre - Puceron de la pomme de terre",
    71: "Pomme de terre - Teigne de la pomme de terre",
    72: "Pomme de terre - Psylle de la pomme de terre",
    73: "Poivron - Puceron du poivron",
    74: "Poivron - Thrips du poivron",
    75: "Poivron - Acarien du poivron",
    76: "Concombre - Puceron du concombre",
    77: "Concombre - Mouche du melon",
    78: "Concombre - Thrips du concombre",
    79: "Aubergine - Noctuelle de l'aubergine",
    80: "Aubergine - Acarien de l'aubergine",
    81: "Haricot - Chrysomèle du haricot",
    82: "Haricot - Puceron noir du haricot",
    83: "Arachide - Puceron de l'arachide",
    84: "Arachide - Thrips de l'arachide",
    85: "Arachide - Ver de l'arachide",
    86: "Tournesol - Charançon du tournesol",
    87: "Tournesol - Ver du tournesol",
    88: "Colza - Méligèthe du colza",
    89: "Colza - Charançon de la tige du colza",
    90: "Colza - Altise du colza",
    91: "Betterave - Puceron noir de la betterave",
    92: "Betterave - Ver de la betterave",
    93: "Laitue - Puceron de la laitue",
    94: "Laitue - Noctuelle de la laitue",
    95: "Carotte - Mouche de la carotte",
    96: "Carotte - Puceron de la carotte",
    97: "Oignon - Thrips de l'oignon",
    98: "Oignon - Mouche de l'oignon",
    99: "Ravageur générique - Criquet",
    100: "Ravageur générique - Sauterelle",
    101: "Ravageur générique - Scarabée"
}

# Pest danger levels and treatment recommendations
PEST_INFO = {
    "doryphore": {
        "danger": "Élevé",
        "impact": "Défoliation complète possible",
        "treatment": "Ramassage manuel, Bacillus thuringiensis, spinosad",
        "prevention": "Rotation des cultures, destruction des résidus"
    },
    "puceron": {
        "danger": "Modéré",
        "impact": "Affaiblissement, transmission de virus",
        "treatment": "Savon noir, huile de neem, coccinelles",
        "prevention": "Favoriser les auxiliaires, éviter excès d'azote"
    },
    "aleurode": {
        "danger": "Élevé",
        "impact": "Miellat, fumagine, transmission de virus",
        "treatment": "Piégeage jaune, savon insecticide, encarsia",
        "prevention": "Filets anti-insectes, hygiène des serres"
    },
    "thrips": {
        "danger": "Modéré",
        "impact": "Dégâts sur feuilles et fruits",
        "treatment": "Spinosad, acariens prédateurs",
        "prevention": "Pièges bleus collants, élimination des mauvaises herbes"
    },
    "acarien": {
        "danger": "Modéré",
        "impact": "Dessèchement, décoloration des feuilles",
        "treatment": "Soufre, acaricides spécifiques",
        "prevention": "Irrigation régulière, phytoséiides"
    },
    "pyrale": {
        "danger": "Élevé",
        "impact": "Dégâts dans les tiges et épis",
        "treatment": "Trichogrammes, Bacillus thuringiensis",
        "prevention": "Broyage des résidus, pièges à phéromones"
    },
    "cicadelle": {
        "danger": "Modéré",
        "impact": "Transmission de phytoplasmes",
        "treatment": "Kaolin, huiles minérales",
        "prevention": "Enherbement maîtrisé, pièges chromatiques"
    },
    "default": {
        "danger": "Modéré",
        "impact": "Variable selon l'espèce",
        "treatment": "Identification précise requise",
        "prevention": "Surveillance régulière, rotation des cultures"
    }
}


def get_pest_info(pest_name: str) -> dict:
    """Get danger level and treatment info for a pest"""
    pest_lower = pest_name.lower()
    for key, info in PEST_INFO.items():
        if key in pest_lower:
            return info
    return PEST_INFO["default"]


@app.post("/analyze/insects")
async def analyze_insects(image: UploadFile = File(...)):
    """
    Analyze image for insect pests using YOLO11s model
    
    Returns:
        - detections: List of detected insects with bounding boxes
        - total_count: Total number of insects detected
        - danger_level: Overall danger assessment
    """
    global pest_detection_model
    
    # Load model if not already loaded
    if pest_detection_model is None:
        logger.info("📦 Loading pest detection model (lazy load)...")
        try:
            load_pest_detection_model()
        except Exception as e:
            logger.error(f"Failed to load pest detection model: {e}")
            raise HTTPException(
                status_code=503,
                detail="Pest detection model not available. Please check server logs."
            )
    
    try:
        # Read and process image
        contents = await image.read()
        pil_image = Image.open(io.BytesIO(contents))
        
        # Convert to RGB if needed
        if pil_image.mode != 'RGB':
            pil_image = pil_image.convert('RGB')
        
        image_width, image_height = pil_image.size
        logger.info(f"🔍 Analyzing image for pests: {image_width}x{image_height}")
        
        # Run YOLO11s pest detection
        results = pest_detection_model(pil_image, conf=0.25, verbose=False)
        
        detections = []
        danger_counts = {"Faible": 0, "Modéré": 0, "Élevé": 0}
        
        for result in results:
            if result.boxes is not None:
                for box in result.boxes:
                    # Get class and confidence
                    class_id = int(box.cls[0])
                    confidence = float(box.conf[0])
                    
                    # Get class name
                    class_name = IP102_CLASS_NAMES.get(class_id, f"Insecte #{class_id}")
                    
                    # Get bounding box (xyxy format)
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    
                    # Convert to percentage
                    x1_pct = (x1 / image_width) * 100
                    y1_pct = (y1 / image_height) * 100
                    x2_pct = (x2 / image_width) * 100
                    y2_pct = (y2 / image_height) * 100
                    
                    # Get pest info
                    pest_info = get_pest_info(class_name)
                    danger_counts[pest_info["danger"]] += 1
                    
                    detections.append({
                        "class": class_name,
                        "class_id": class_id,
                        "confidence": confidence,
                        "bbox": {
                            "x1": x1_pct,
                            "y1": y1_pct,
                            "x2": x2_pct,
                            "y2": y2_pct,
                            "width": x2_pct - x1_pct,
                            "height": y2_pct - y1_pct
                        },
                        "danger_level": pest_info["danger"],
                        "impact": pest_info["impact"],
                        "treatment": pest_info["treatment"],
                        "prevention": pest_info["prevention"]
                    })
        
        # Sort by confidence descending
        detections.sort(key=lambda x: x["confidence"], reverse=True)
        
        # Determine overall danger level
        if danger_counts["Élevé"] > 0:
            overall_danger = "Élevé"
        elif danger_counts["Modéré"] > 0:
            overall_danger = "Modéré" 
        elif len(detections) > 0:
            overall_danger = "Faible"
        else:
            overall_danger = "Aucun"
        
        logger.info(f"✅ Pest detection complete: {len(detections)} pests found, danger: {overall_danger}")
        
        return JSONResponse(content={
            "success": True,
            "model": "YOLO11s Pest Detection",
            "dataset": "IP102 (102 espèces)",
            "image_size": {"width": image_width, "height": image_height},
            "detections": detections,
            "total_count": len(detections),
            "danger_level": overall_danger,
            "danger_breakdown": danger_counts,
            "message": f"{len(detections)} ravageur(s) détecté(s)" if detections else "Aucun ravageur détecté - Culture saine"
        })
        
    except Exception as e:
        logger.error(f"❌ Pest detection error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Pest detection failed: {str(e)}")


def load_vit_model():
    """Load ViT PlantDoc model (from local .pth or HuggingFace Hub)"""
    global vit_model, vit_classes, vit_transform
    import json
    from transformers import ViTForImageClassification

    models_dir = Path(__file__).parent.parent / "models"
    pth_path   = models_dir / "vit_plantdoc_best.pth"
    json_path  = models_dir / "vit_plantdoc_classes.json"

    # ── Classes metadata (embedded fallback so Render works without the JSON) ──
    FALLBACK_CLASSES = [
        "Apple_Scab_Leaf","Apple_leaf","Apple_rust_leaf","Bell_pepper_leaf",
        "Bell_pepper_leaf_spot","Blueberry_leaf","Cherry_leaf","Corn_Gray_leaf_spot",
        "Corn_leaf_blight","Corn_rust_leaf","Peach_leaf","Potato_leaf_early_blight",
        "Potato_leaf_late_blight","Raspberry_leaf","Soyabean_leaf",
        "Squash_Powdery_mildew_leaf","Strawberry_leaf","Tomato_Early_blight_leaf",
        "Tomato_Septoria_leaf_spot","Tomato_leaf","Tomato_leaf_bacterial_spot",
        "Tomato_leaf_late_blight","Tomato_leaf_mosaic_virus","Tomato_leaf_yellow_virus",
        "Tomato_mold_leaf","Tomato_two_spotted_spider_mites_leaf","grape_leaf",
        "grape_leaf_black_rot",
    ]

    if json_path.exists():
        with open(json_path, "r") as f:
            meta = json.load(f)
        classes = meta["classes"]
        num_classes = meta["num_classes"]
        id2label = {int(k): v for k, v in meta["id2label"].items()}
    else:
        logger.warning("vit_plantdoc_classes.json not found — using fallback class list")
        classes = FALLBACK_CLASSES
        num_classes = len(classes)
        id2label = {i: c for i, c in enumerate(classes)}
        meta = {"classes": classes, "num_classes": num_classes,
                "id2label": {str(k): v for k, v in id2label.items()}}

    label2id = {v: k for k, v in id2label.items()}

    vit_model = ViTForImageClassification.from_pretrained(
        "google/vit-base-patch16-224-in21k",
        num_labels=num_classes,
        id2label=id2label,
        label2id=label2id,
        ignore_mismatched_sizes=True,
    )

    if not pth_path.exists():
        logger.info("📥 Downloading vit_plantdoc_best.pth from HuggingFace Hub...")
        try:
            from huggingface_hub import hf_hub_download
            downloaded = hf_hub_download(
                repo_id="aladinhabibi/vit-plantdoc",
                filename="vit_plantdoc_best.pth",
                local_dir=str(models_dir),
            )
            pth_path = Path(downloaded)
            logger.info(f"✅ Downloaded to {pth_path}")
        except Exception as e:
            logger.warning(f"⚠️  Could not download .pth: {e} — using base ViT weights")

    if pth_path.exists():
        vit_model.load_state_dict(torch.load(str(pth_path), map_location="cpu"))
        logger.info(f"✅ ViT fine-tuned weights loaded from {pth_path.name}")
    else:
        logger.warning("vit_plantdoc_best.pth not found — using base ViT weights (not fine-tuned)")

    vit_model.eval()
    for p in vit_model.parameters():
        p.requires_grad = False

    vit_classes = meta
    vit_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5]),
    ])
    logger.info(f"✅ ViT PlantDoc ready — {num_classes} classes")


@app.post("/classify/vit")
async def classify_vit(image: str = Form(...)):
    """Classify plant disease using ViT trained on PlantDoc (28 classes)"""
    global vit_model
    if vit_model is None:
        load_vit_model()
    if vit_model is None:
        raise HTTPException(status_code=503, detail="ViT model not available")

    if image.startswith("data:image"):
        image = image.split(",")[1]
    pil_image = Image.open(io.BytesIO(base64.b64decode(image))).convert("RGB")

    tensor = vit_transform(pil_image).unsqueeze(0)
    with torch.no_grad():
        logits = vit_model(pixel_values=tensor).logits
        probs  = torch.nn.functional.softmax(logits[0], dim=0)
        top3_probs, top3_idx = torch.topk(probs, 3)

    id2label = vit_classes["id2label"]
    top3 = [
        {"class": id2label[str(int(idx))], "confidence": round(float(p), 4)}
        for idx, p in zip(top3_idx, top3_probs)
    ]
    primary = top3[0]
    is_healthy = is_healthy_class(primary["class"])

    return JSONResponse({
        "success":     True,
        "disease":     primary["class"],
        "confidence":  int(primary["confidence"] * 100),
        "isHealthy":   is_healthy,
        "generalStatus": "Saine" if is_healthy else "Malade",
        "top3":        top3,
        "source":      "vit-plantdoc",
    })


if __name__ == "__main__":
    host = os.getenv("API_HOST", "0.0.0.0")
    # Support PORT env var from Railway/Render/Fly.io (they use PORT instead of API_PORT)
    port = int(os.getenv("PORT", os.getenv("API_PORT", 8000)))
    reload = os.getenv("API_RELOAD", "true").lower() == "true"
    
    uvicorn.run(
        "api.main:app",
        host=host,
        port=port,
        reload=reload
    )

