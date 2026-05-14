"""
Dataset browsing API — serves images from the PlantVillage dataset.
"""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path
import os
import random

router = APIRouter(prefix="/dataset", tags=["Dataset"])

# Dataset root path — adjust based on deployment
DATASET_ROOT = Path(__file__).parent.parent.parent / "archive" / "New Plant Diseases Dataset(Augmented)" / "New Plant Diseases Dataset(Augmented)"

# Mapping: disease_id → dataset folder name(s)
DISEASE_FOLDER_MAP = {
    "apple_scab": ["Apple___Apple_scab"],
    "apple_black_rot": ["Apple___Black_rot"],
    "apple_cedar_rust": ["Apple___Cedar_apple_rust"],
    "apple_healthy": ["Apple___healthy"],
    "blueberry_healthy": ["Blueberry___healthy"],
    "cherry_powdery_mildew": ["Cherry_(including_sour)___Powdery_mildew"],
    "cherry_healthy": ["Cherry_(including_sour)___healthy"],
    "corn_gray_leaf_spot": ["Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot"],
    "corn_common_rust": ["Corn_(maize)___Common_rust_"],
    "corn_northern_leaf_blight": ["Corn_(maize)___Northern_Leaf_Blight"],
    "corn_healthy": ["Corn_(maize)___healthy"],
    "grape_black_rot": ["Grape___Black_rot"],
    "grape_esca": ["Grape___Esca_(Black_Measles)"],
    "grape_leaf_blight": ["Grape___Leaf_blight_(Isariopsis_Leaf_Spot)"],
    "grape_healthy": ["Grape___healthy"],
    "orange_citrus_greening": ["Orange___Haunglongbing_(Citrus_greening)"],
    "peach_bacterial_spot": ["Peach___Bacterial_spot"],
    "peach_healthy": ["Peach___healthy"],
    "pepper_bacterial_spot": ["Pepper,_bell___Bacterial_spot"],
    "pepper_healthy": ["Pepper,_bell___healthy"],
    "potato_early_blight": ["Potato___Early_blight"],
    "potato_late_blight": ["Potato___Late_blight"],
    "potato_healthy": ["Potato___healthy"],
    "raspberry_healthy": ["Raspberry___healthy"],
    "soybean_healthy": ["Soybean___healthy"],
    "squash_powdery_mildew": ["Squash___Powdery_mildew"],
    "strawberry_leaf_scorch": ["Strawberry___Leaf_scorch"],
    "strawberry_healthy": ["Strawberry___healthy"],
    "tomato_bacterial_spot": ["Tomato___Bacterial_spot"],
    "tomato_early_blight": ["Tomato___Early_blight"],
    "tomato_late_blight": ["Tomato___Late_blight"],
    "tomato_leaf_mold": ["Tomato___Leaf_Mold"],
    "tomato_septoria": ["Tomato___Septoria_leaf_spot"],
    "tomato_spider_mites": ["Tomato___Spider_mites Two-spotted_spider_mite"],
    "tomato_target_spot": ["Tomato___Target_Spot"],
    "tomato_yellow_leaf_curl": ["Tomato___Tomato_Yellow_Leaf_Curl_Virus"],
    "tomato_mosaic_virus": ["Tomato___Tomato_mosaic_virus"],
    "tomato_healthy": ["Tomato___healthy"],
}


def _get_image_files(disease_id: str, split: str = "train") -> list[Path]:
    """Get all image files for a disease class."""
    folders = DISEASE_FOLDER_MAP.get(disease_id, [])
    images = []
    for folder_name in folders:
        folder_path = DATASET_ROOT / split / folder_name
        if folder_path.exists():
            images.extend(
                p for p in folder_path.iterdir()
                if p.suffix.lower() in ('.jpg', '.jpeg', '.png', '.bmp')
            )
    return sorted(images, key=lambda p: p.name)


@router.get("/classes")
async def list_classes():
    """List all available disease classes with image counts."""
    classes = []
    for disease_id, folders in DISEASE_FOLDER_MAP.items():
        total = 0
        for folder_name in folders:
            train_path = DATASET_ROOT / "train" / folder_name
            valid_path = DATASET_ROOT / "valid" / folder_name
            if train_path.exists():
                total += sum(1 for _ in train_path.iterdir() if _.is_file())
            if valid_path.exists():
                total += sum(1 for _ in valid_path.iterdir() if _.is_file())
        classes.append({
            "id": disease_id,
            "folders": folders,
            "totalImages": total,
        })
    return {"classes": classes, "totalClasses": len(classes)}


@router.get("/images/{disease_id}")
async def list_images(
    disease_id: str,
    split: str = Query("train", pattern="^(train|valid)$"),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
):
    """List images for a disease class with pagination."""
    if disease_id not in DISEASE_FOLDER_MAP:
        raise HTTPException(status_code=404, detail=f"Disease class '{disease_id}' not found")

    images = _get_image_files(disease_id, split)
    total = len(images)
    start = (page - 1) * per_page
    end = start + per_page
    page_images = images[start:end]

    return {
        "diseaseId": disease_id,
        "split": split,
        "total": total,
        "page": page,
        "perPage": per_page,
        "totalPages": (total + per_page - 1) // per_page,
        "images": [
            {
                "filename": img.name,
                "url": f"/dataset/image/{disease_id}/{img.name}?split={split}",
            }
            for img in page_images
        ],
    }


@router.get("/image/{disease_id}/{filename}")
async def get_image(
    disease_id: str,
    filename: str,
    split: str = Query("train", pattern="^(train|valid)$"),
):
    """Serve a single image file."""
    if disease_id not in DISEASE_FOLDER_MAP:
        raise HTTPException(status_code=404, detail="Disease class not found")

    # Sanitize filename to prevent path traversal
    safe_filename = Path(filename).name
    if safe_filename != filename or '..' in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")

    folders = DISEASE_FOLDER_MAP[disease_id]
    for folder_name in folders:
        image_path = DATASET_ROOT / split / folder_name / safe_filename
        if image_path.exists() and image_path.is_file():
            return FileResponse(
                path=str(image_path),
                media_type="image/jpeg",
                headers={"Cache-Control": "public, max-age=86400"},
            )

    raise HTTPException(status_code=404, detail="Image not found")


@router.get("/random/{disease_id}")
async def get_random_images(
    disease_id: str,
    count: int = Query(5, ge=1, le=20),
    split: str = Query("train", pattern="^(train|valid)$"),
):
    """Get random sample images for a disease class."""
    if disease_id not in DISEASE_FOLDER_MAP:
        raise HTTPException(status_code=404, detail="Disease class not found")

    images = _get_image_files(disease_id, split)
    if not images:
        return {"diseaseId": disease_id, "images": []}

    sample = random.sample(images, min(count, len(images)))
    return {
        "diseaseId": disease_id,
        "total": len(images),
        "images": [
            {
                "filename": img.name,
                "url": f"/dataset/image/{disease_id}/{img.name}?split={split}",
            }
            for img in sample
        ],
    }


@router.get("/stats")
async def dataset_stats():
    """Get overall dataset statistics."""
    total_images = 0
    class_stats = []
    for disease_id, folders in DISEASE_FOLDER_MAP.items():
        count = 0
        for folder_name in folders:
            for split in ("train", "valid"):
                p = DATASET_ROOT / split / folder_name
                if p.exists():
                    count += sum(1 for _ in p.iterdir() if _.is_file())
        total_images += count
        class_stats.append({"id": disease_id, "count": count})

    return {
        "totalImages": total_images,
        "totalClasses": len(DISEASE_FOLDER_MAP),
        "splits": ["train", "valid"],
        "classStats": sorted(class_stats, key=lambda x: x["count"], reverse=True),
    }
