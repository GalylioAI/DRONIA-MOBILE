"""
Extract multiple sample images per PlantVillage class (6 per class)
from both train and valid sets, copy to assets/data/disease_images/,
and update the JSON knowledge base with image arrays.
"""
import os, shutil, json, re, random

BASE = os.path.dirname(__file__)
TRAIN_DIR = os.path.join(BASE, "archive", "New Plant Diseases Dataset(Augmented)",
                         "New Plant Diseases Dataset(Augmented)", "train")
VALID_DIR = os.path.join(BASE, "archive", "New Plant Diseases Dataset(Augmented)",
                         "New Plant Diseases Dataset(Augmented)", "valid")
OUTPUT_DIR = os.path.join(BASE, "assets", "data", "disease_images")
JSON_PATH = os.path.join(BASE, "assets", "data", "disease_knowledge_base.json")

IMAGES_PER_CLASS = 6

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


def get_original_images(folder_path):
    """Get non-augmented images first, then augmented ones."""
    if not os.path.isdir(folder_path):
        return []
    all_imgs = [f for f in sorted(os.listdir(folder_path))
                if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    originals = [f for f in all_imgs
                 if not re.search(r'_(90|180|270)deg|Flip|new\d+deg', f)]
    augmented = [f for f in all_imgs if f not in originals]
    return originals + augmented


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Clear old images
    for f in os.listdir(OUTPUT_DIR):
        os.remove(os.path.join(OUTPUT_DIR, f))

    image_map = {}  # disease_id -> list of asset paths
    total = 0

    for folder_name, disease_id in FOLDER_TO_ID.items():
        # Combine images from train + valid for variety
        train_imgs = get_original_images(os.path.join(TRAIN_DIR, folder_name))
        valid_imgs = get_original_images(os.path.join(VALID_DIR, folder_name))

        # Pick diverse samples: 4 from train, 2 from valid
        random.seed(42)  # reproducible
        train_picks = train_imgs[:4] if len(train_imgs) >= 4 else train_imgs
        valid_picks = valid_imgs[:2] if len(valid_imgs) >= 2 else valid_imgs

        selected = []
        for i, img in enumerate(train_picks):
            ext = os.path.splitext(img)[1].lower()
            dest_name = f"{disease_id}_{i+1}{ext}"
            src = os.path.join(TRAIN_DIR, folder_name, img)
            shutil.copy2(src, os.path.join(OUTPUT_DIR, dest_name))
            selected.append(f"assets/data/disease_images/{dest_name}")

        for i, img in enumerate(valid_picks):
            ext = os.path.splitext(img)[1].lower()
            dest_name = f"{disease_id}_{len(train_picks)+i+1}{ext}"
            src = os.path.join(VALID_DIR, folder_name, img)
            shutil.copy2(src, os.path.join(OUTPUT_DIR, dest_name))
            selected.append(f"assets/data/disease_images/{dest_name}")

        image_map[disease_id] = selected
        total += len(selected)
        print(f"✅ {disease_id}: {len(selected)} images")

    # Update JSON
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    for disease in data["diseases"]:
        did = disease["id"]
        if did in image_map:
            disease["images"] = image_map[did]
            disease["imagePath"] = image_map[did][0]  # keep first as thumbnail
            disease["imageCount"] = len(image_map[did])

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 Done! Copied {total} images ({len(image_map)} classes × ~{IMAGES_PER_CLASS} each)")
    print(f"📁 Output: {OUTPUT_DIR}")
    print(f"📝 Updated: {JSON_PATH}")


if __name__ == "__main__":
    main()
