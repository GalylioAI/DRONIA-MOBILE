# Plant Disease Classification - Supported Classes

The EfficientNet model supports **38 plant disease classes** from the PlantVillage dataset.

## 🌿 All Supported Diseases

| # | Class Name | French Name | Plant |
|---|------------|-------------|-------|
| 0 | Apple___Apple_scab | Tavelure du pommier | 🍎 Pomme |
| 1 | Apple___Black_rot | Pourriture noire (Pomme) | 🍎 Pomme |
| 2 | Apple___Cedar_apple_rust | Rouille du cèdre | 🍎 Pomme |
| 3 | Apple___healthy | Pomme saine | 🍎 Pomme |
| 4 | Blueberry___healthy | Myrtille saine | 🫐 Myrtille |
| 5 | Cherry_(including_sour)___Powdery_mildew | Oïdium (Cerise) | 🍒 Cerise |
| 6 | Cherry_(including_sour)___healthy | Cerise saine | 🍒 Cerise |
| 7 | Corn_(maize)___Cercospora_leaf_spot_Gray_leaf_spot | Tache grise des feuilles (Maïs) | 🌽 Maïs |
| 8 | Corn_(maize)___Common_rust | Rouille commune (Maïs) | 🌽 Maïs |
| 9 | Corn_(maize)___Northern_Leaf_Blight | Brûlure septentrionale (Maïs) | 🌽 Maïs |
| 10 | Corn_(maize)___healthy | Maïs sain | 🌽 Maïs |
| 11 | Grape___Black_rot | Pourriture noire (Raisin) | 🍇 Raisin |
| 12 | Grape___Esca_(Black_Measles) | Esca | 🍇 Raisin |
| 13 | Grape___Leaf_blight_(Isariopsis_Leaf_Spot) | Brûlure des feuilles (Raisin) | 🍇 Raisin |
| 14 | Grape___healthy | Raisin sain | 🍇 Raisin |
| 15 | Orange___Haunglongbing_(Citrus_greening) | Maladie du verdissement (Agrumes) | 🍊 Orange |
| 16 | Peach___Bacterial_spot | Tache bactérienne (Pêche) | 🍑 Pêche |
| 17 | Peach___healthy | Pêche saine | 🍑 Pêche |
| 18 | Pepper,_bell___Bacterial_spot | Tache bactérienne (Poivron) | 🫑 Poivron |
| 19 | Pepper,_bell___healthy | Poivron sain | 🫑 Poivron |
| 20 | Potato___Early_blight | Alternariose (Pomme de terre) | 🥔 Pomme de terre |
| 21 | Potato___Late_blight | Mildiou (Pomme de terre) | 🥔 Pomme de terre |
| 22 | Potato___healthy | Pomme de terre saine | 🥔 Pomme de terre |
| 23 | Raspberry___healthy | Framboise saine | 🫐 Framboise |
| 24 | Soybean___healthy | Soja sain | 🫘 Soja |
| 25 | Squash___Powdery_mildew | Oïdium (Courge) | 🥒 Courge |
| 26 | Strawberry___Leaf_scorch | Brûlure des feuilles (Fraise) | 🍓 Fraise |
| 27 | Strawberry___healthy | Fraise saine | 🍓 Fraise |
| 28 | Tomato___Bacterial_spot | Tache bactérienne (Tomate) | 🍅 Tomate |
| 29 | Tomato___Early_blight | Alternariose (Tomate) | 🍅 Tomate |
| 30 | Tomato___Late_blight | Mildiou (Tomate) | 🍅 Tomate |
| 31 | Tomato___Leaf_Mold | Moisissure des feuilles (Tomate) | 🍅 Tomate |
| 32 | Tomato___Septoria_leaf_spot | Septoriose (Tomate) | 🍅 Tomate |
| 33 | Tomato___Spider_mites_Two-spotted_spider_mite | Acariens (Tomate) | 🍅 Tomate |
| 34 | Tomato___Target_Spot | Taches ciblées (Tomate) | 🍅 Tomate |
| 35 | Tomato___Tomato_Yellow_Leaf_Curl_Virus | Virus de l'enroulement (Tomate) | 🍅 Tomate |
| 36 | Tomato___Tomato_mosaic_virus | Virus de la mosaïque (Tomate) | 🍅 Tomate |
| 37 | Tomato___healthy | Tomate saine | 🍅 Tomate |

## 📊 Summary by Plant

| Plant | Total Classes | Diseases | Healthy |
|-------|---------------|----------|---------|
| 🍅 Tomato | 10 | 9 | 1 |
| 🍎 Apple | 4 | 3 | 1 |
| 🌽 Corn | 4 | 3 | 1 |
| 🍇 Grape | 4 | 3 | 1 |
| 🥔 Potato | 3 | 2 | 1 |
| 🫑 Pepper | 2 | 1 | 1 |
| 🍒 Cherry | 2 | 1 | 1 |
| 🍑 Peach | 2 | 1 | 1 |
| 🍓 Strawberry | 2 | 1 | 1 |
| 🍊 Orange | 1 | 1 | 0 |
| 🥒 Squash | 1 | 1 | 0 |
| 🫐 Blueberry | 1 | 0 | 1 |
| 🫐 Raspberry | 1 | 0 | 1 |
| 🫘 Soybean | 1 | 0 | 1 |

**Total: 38 classes, 26 diseases, 12 healthy classes**

## 🔍 Disease Details

### Fungal Diseases (Most Common)
- **Alternariose (Early Blight)** - Affects potatoes and tomatoes
- **Mildiou (Late Blight)** - Affects potatoes and tomatoes
- **Oïdium (Powdery Mildew)** - Affects cherry and squash
- **Septoriose** - Affects tomatoes
- **Tavelure (Apple Scab)** - Affects apples
- **Pourriture noire (Black Rot)** - Affects apples and grapes
- **Rouille (Rust)** - Affects corn and apples
- **Esca** - Affects grapes

### Bacterial Diseases
- **Tache bactérienne (Bacterial Spot)** - Affects peppers, peaches, tomatoes

### Viral Diseases
- **Virus de l'enroulement (Yellow Leaf Curl Virus)** - Affects tomatoes
- **Virus de la mosaïque (Mosaic Virus)** - Affects tomatoes
- **Maladie du verdissement (Citrus Greening)** - Affects oranges

### Pest Damage
- **Acariens (Spider Mites)** - Affects tomatoes

## 🚀 Training Instructions

To train the model with all 38 classes, see [TRAIN_FULL_PLANTVILLAGE.md](./TRAIN_FULL_PLANTVILLAGE.md).

