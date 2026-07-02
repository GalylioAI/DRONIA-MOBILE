"""
Image analysis utilities for detecting disease symptoms
"""

import numpy as np
from PIL import Image
import cv2


def detect_disease_symptoms(image: Image.Image) -> dict:
    """
    Analyze image to detect disease symptoms (yellow, brown, black spots)
    and calculate affected surface percentage and severity.
    
    Args:
        image: PIL Image (RGB)
        
    Returns:
        dict with:
            - affected_surface: percentage of image showing disease symptoms (0-100)
            - severity: "Légère", "Modérée", or "Élevée" based on affected surface
            - symptom_areas: list of detected symptom regions
    """
    # Convert PIL to numpy array
    img_array = np.array(image)
    
    # Convert RGB to HSV for better color detection
    hsv = cv2.cvtColor(img_array, cv2.COLOR_RGB2HSV)
    
    # Define color ranges for disease symptoms in HSV
    # Yellow symptoms (early disease, chlorosis) - yellow/brownish yellow
    yellow_lower = np.array([15, 80, 80])
    yellow_upper = np.array([35, 255, 255])
    yellow_mask = cv2.inRange(hsv, yellow_lower, yellow_upper)
    
    # Brown symptoms (moderate disease, necrosis) - brown/tan colors
    brown_lower = np.array([5, 100, 50])
    brown_upper = np.array([25, 255, 180])
    brown_mask = cv2.inRange(hsv, brown_lower, brown_upper)
    
    # Dark brown/black symptoms (severe disease, dead tissue) - very dark brown/black
    # More specific: low saturation, low value (dark colors)
    dark_lower = np.array([0, 0, 0])
    dark_upper = np.array([180, 100, 100])  # Dark colors with low saturation
    dark_mask = cv2.inRange(hsv, dark_lower, dark_upper)
    
    # Also detect dark brown specifically (hue 5-20, low value)
    dark_brown_lower = np.array([5, 50, 0])
    dark_brown_upper = np.array([20, 255, 100])
    dark_brown_mask = cv2.inRange(hsv, dark_brown_lower, dark_brown_upper)
    
    # Combine all symptom masks
    combined_mask = cv2.bitwise_or(yellow_mask, cv2.bitwise_or(brown_mask, cv2.bitwise_or(dark_mask, dark_brown_mask)))
    
    # Remove small noise
    kernel = np.ones((5, 5), np.uint8)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)
    
    # Calculate affected surface percentage
    total_pixels = img_array.shape[0] * img_array.shape[1]
    affected_pixels = np.sum(combined_mask > 0)
    affected_surface = (affected_pixels / total_pixels) * 100 if total_pixels > 0 else 0
    
    # Determine severity based on affected surface
    if affected_surface >= 30:
        severity = "Élevée"
    elif affected_surface >= 10:
        severity = "Modérée"
    elif affected_surface > 0:
        severity = "Légère"
    else:
        severity = "Nulle"
    
    # Find contours of disease areas
    contours, _ = cv2.findContours(combined_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    img_h, img_w = img_array.shape[:2]
    min_area = total_pixels * 0.001  # 0.1% of image
    symptom_areas = []

    for contour in contours:
        area = cv2.contourArea(contour)
        if area <= min_area:
            continue

        x, y, w, h = cv2.boundingRect(contour)

        # Simplify contour with Douglas-Peucker to reduce point count
        epsilon = 0.02 * cv2.arcLength(contour, True)
        approx  = cv2.approxPolyDP(contour, epsilon, True)

        # Normalize contour points to 0–100 percentage space
        points_pct = [
            [round(float(pt[0][0]) / img_w * 100, 2),
             round(float(pt[0][1]) / img_h * 100, 2)]
            for pt in approx
        ]

        symptom_areas.append({
            'x':              int(x),
            'y':              int(y),
            'width':          int(w),
            'height':         int(h),
            'area':           float(area),
            'area_percentage': float((area / total_pixels) * 100),
            'contourPoints':  points_pct,   # polygon points in %
        })

    # Sort by area descending, keep top 15
    symptom_areas.sort(key=lambda z: z['area'], reverse=True)

    return {
        'affected_surface': round(affected_surface, 2),
        'severity':         severity,
        'symptom_count':    len(symptom_areas),
        'symptom_areas':    symptom_areas[:15],
    }


def analyze_leaf_health(image: Image.Image) -> dict:
    """
    Comprehensive leaf health analysis combining color detection and image statistics.
    
    Args:
        image: PIL Image (RGB)
        
    Returns:
        dict with health metrics
    """
    # Get basic image analysis
    symptoms = detect_disease_symptoms(image)
    
    # Convert to numpy for additional analysis
    img_array = np.array(image)
    
    # Calculate color statistics
    # Healthy green leaves typically have high green channel values
    green_channel = img_array[:, :, 1]
    green_mean = np.mean(green_channel)
    green_std = np.std(green_channel)
    
    # Calculate overall brightness (diseased areas are often darker)
    gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
    brightness_mean = np.mean(gray)
    
    # Health score (0-100, higher is healthier)
    # Based on green content and brightness
    green_score = min(100, (green_mean / 255) * 100)
    brightness_score = min(100, (brightness_mean / 255) * 100)
    health_score = (green_score * 0.6 + brightness_score * 0.4) - (symptoms['affected_surface'] * 0.5)
    health_score = max(0, min(100, health_score))
    
    return {
        **symptoms,
        'health_score': round(health_score, 2),
        'green_content': round(green_mean, 2),
        'brightness': round(brightness_mean, 2)
    }

