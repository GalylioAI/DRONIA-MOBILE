"""
Extract one sample image per PlantVillage class from the augmented dataset
and copy them into assets/data/disease_images/ for the Flutter app.
Also updates the JSON knowledge base with image paths.
"""
import os, shutil, json, re

DATASET_DIR = os.path.join(
    os.path.dirname(__file__),
    "archive",
    "New Plant Diseases Dataset(Augmented)",
    "New Plant Diseases Dataset(Augmented)",
    "train",
)
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "assets", "data", "disease_images")
JSON_PATH = os.path.join(os.path.dirname(__file__), "assets", "data", "disease_knowledge_base.json")

# Mapping from dataset folder name → disease id in our JSON
FOLDER_TO_ID = {
    "Apple___Apple_scab": "apple_scab",
    "Apple___Black_rot": "apple_black_rot",
    "Apple___Cedar_apple_rust": "apple_cedar_rust",
    "Apple___healthy": "apple_healthy",
    "Blueberry___healthy": "blueberry_healthy",
    "Cherry_(including_sour)___Powdery_mildew": "cherry_powdery_mildew",
    "Cherry_(including_sour)___healthy": "cherry_healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "corn_gray_leaf_spot",
    "Corn_(maize)___Common_rust_": "corn_common_rust",
    "Corn_(maize)___Northern_Leaf_Blight": "corn_northern_leaf_blight",
    "Corn_(maize)___healthy": "corn_healthy",
    "Grape___Black_rot": "grape_black_rot",
    "Grape___Esca_(Black_Measles)": "grape_esca",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "grape_leaf_blight",
    "Grape___healthy": "grape_healthy",
    "Orange___Haunglongbing_(Citrus_greening)": "orange_citrus_greening",
    "Peach___Bacterial_spot": "peach_bacterial_spot",
    "Peach___healthy": "peach_healthy",
    "Pepper,_bell___Bacterial_spot": "pepper_bacterial_spot",
    "Pepper,_bell___healthy": "pepper_healthy",
    "Potato___Early_blight": "potato_early_blight",
    "Potato___Late_blight": "potato_late_blight",
    "Potato___healthy": "potato_healthy",
    "Raspberry___healthy": "raspberry_healthy",
    "Soybean___healthy": "soybean_healthy",
    "Squash___Powdery_mildew": "squash_powdery_mildew",
    "Strawberry___Leaf_scorch": "strawberry_leaf_scorch",
    "Strawberry___healthy": "strawberry_healthy",
    "Tomato___Bacterial_spot": "tomato_bacterial_spot",
    "Tomato___Early_blight": "tomato_early_blight",
    "Tomato___Late_blight": "tomato_late_blight",
    "Tomato___Leaf_Mold": "tomato_leaf_mold",
    "Tomato___Septoria_leaf_spot": "tomato_septoria",
    "Tomato___Spider_mites Two-spotted_spider_mite": "tomato_spider_mites",
    "Tomato___Target_Spot": "tomato_target_spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "tomato_yellow_leaf_curl",
    "Tomato___Tomato_mosaic_virus": "tomato_mosaic_virus",
    "Tomato___healthy": "tomato_healthy",
}


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    copied = {}

    for folder_name, disease_id in FOLDER_TO_ID.items():
        folder_path = os.path.join(DATASET_DIR, folder_name)
        if not os.path.isdir(folder_path):
            print(f"⚠️  Missing folder: {folder_name}")
            continue

        # Pick the first non-augmented image (no _90deg, _270deg, etc.)
        images = sorted(os.listdir(folder_path))
        chosen = None
        for img in images:
            if img.lower().endswith(('.jpg', '.jpeg', '.png')):
                # Prefer originals (no rotation/flip suffix)
                if not re.search(r'_(90|180|270)deg|Flip|new\d+deg', img):
                    chosen = img
                    break
        if chosen is None and images:
            chosen = images[0]

        if chosen:
            ext = os.path.splitext(chosen)[1].lower()
            dest_name = f"{disease_id}{ext}"
            shutil.copy2(
                os.path.join(folder_path, chosen),
                os.path.join(OUTPUT_DIR, dest_name),
            )
            copied[disease_id] = f"assets/data/disease_images/{dest_name}"
            print(f"✅ {disease_id} ← {chosen}")

    # Update the JSON knowledge base with image paths
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    for disease in data["diseases"]:
        did = disease["id"]
        if did in copied:
            disease["imagePath"] = copied[did]

    # Also add healthy class entries with images
    healthy_entries = []
    for folder_name, disease_id in FOLDER_TO_ID.items():
        if "healthy" in disease_id and disease_id in copied:
            crop = disease_id.replace("_healthy", "").replace("_", " ").title()
            # Check if already exists
            existing_ids = {d["id"] for d in data["diseases"]}
            if disease_id not in existing_ids:
                healthy_entries.append({
                    "id": disease_id,
                    "name": f"{crop} (Healthy)",
                    "nameFr": f"{crop} (Sain)",
                    "scientificName": "—",
                    "type": "healthy",
                    "crops": [crop],
                    "cropsFr": [crop],
                    "emoji": "✅",
                    "severity": "none",
                    "detectable": True,
                    "imagePath": copied[disease_id],
                    "symptoms": [],
                    "symptomsFr": [],
                    "conditions": "No disease present — reference for healthy plant tissue.",
                    "conditionsFr": "Aucune maladie présente — référence pour le tissu végétal sain.",
                    "treatments": [],
                    "treatmentsFr": [],
                    "prevention": ["Maintain good agricultural practices"],
                    "riskMonths": [],
                    "spreadMethod": "—"
                })

    data["diseases"].extend(healthy_entries)
    data["totalDiseases"] = len(data["diseases"])

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 Done! Copied {len(copied)} images to {OUTPUT_DIR}")
    print(f"📝 Updated {JSON_PATH} with imagePath fields")
    print(f"➕ Added {len(healthy_entries)} healthy reference entries")


if __name__ == "__main__":
    main()
