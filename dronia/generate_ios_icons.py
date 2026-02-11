#!/usr/bin/env python3
"""
Script to generate iOS app icons with dark background matching Android.
Background color: #0F172A (dark blue)
"""

from PIL import Image, ImageDraw
import os

# Background color (same as Android)
BG_COLOR = (15, 23, 42)  # #0F172A

# iOS icon sizes needed
ICON_SIZES = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-50x50@1x.png", 50),
    ("Icon-App-50x50@2x.png", 100),
    ("Icon-App-57x57@1x.png", 57),
    ("Icon-App-57x57@2x.png", 114),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-72x72@1x.png", 72),
    ("Icon-App-72x72@2x.png", 144),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

def get_output_dir():
    """Get the iOS AppIcon.appiconset directory"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

def find_source_icon():
    """Find the highest resolution source icon"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Check for existing high-res icon
    possible_sources = [
        os.path.join(script_dir, "android", "app", "src", "main", "res", "mipmap-xxxhdpi", "ic_launcher.png"),
        os.path.join(script_dir, "android", "app", "src", "main", "res", "mipmap-xxhdpi", "ic_launcher.png"),
        os.path.join(script_dir, "assets", "images", "logo.png"),
        os.path.join(script_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", "Icon-App-1024x1024@1x.png"),
    ]
    
    for path in possible_sources:
        if os.path.exists(path):
            return path
    
    return None

def create_icon_with_background(source_path, output_path, size):
    """Create an icon with dark background"""
    
    # Create new image with dark background
    img = Image.new('RGBA', (size, size), BG_COLOR + (255,))
    
    if source_path and os.path.exists(source_path):
        # Load source icon
        source = Image.open(source_path).convert('RGBA')
        
        # Calculate padding (10% margin)
        padding = int(size * 0.1)
        icon_size = size - (padding * 2)
        
        # Resize source to fit
        source = source.resize((icon_size, icon_size), Image.LANCZOS)
        
        # Paste centered on background
        img.paste(source, (padding, padding), source)
    else:
        # Create a simple drone icon placeholder
        draw = ImageDraw.Draw(img)
        
        # Draw a simple drone shape (circle with lines)
        center = size // 2
        radius = size // 4
        
        # Main body (green)
        draw.ellipse(
            [center - radius//2, center - radius//2, 
             center + radius//2, center + radius//2],
            fill=(34, 197, 94, 255)  # Green
        )
        
        # Propeller arms
        arm_length = radius
        for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            x1, y1 = center, center
            x2 = center + dx * arm_length
            y2 = center + dy * arm_length
            draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 200), width=max(1, size//50))
            
            # Propeller circles
            prop_radius = radius // 3
            draw.ellipse(
                [x2 - prop_radius, y2 - prop_radius,
                 x2 + prop_radius, y2 + prop_radius],
                outline=(255, 255, 255, 200),
                width=max(1, size//80)
            )
    
    # Convert to RGB (iOS doesn't like RGBA for app icons)
    rgb_img = Image.new('RGB', img.size, BG_COLOR)
    rgb_img.paste(img, mask=img.split()[3] if img.mode == 'RGBA' else None)
    
    rgb_img.save(output_path, 'PNG')
    print(f"  ✓ Created {os.path.basename(output_path)} ({size}x{size})")

def main():
    print("🎨 Generating iOS App Icons with Dark Background")
    print(f"   Background color: #0F172A")
    print()
    
    output_dir = get_output_dir()
    source_icon = find_source_icon()
    
    if source_icon:
        print(f"📱 Using source icon: {os.path.basename(source_icon)}")
    else:
        print("⚠️  No source icon found, creating placeholder icons")
    
    print(f"📁 Output directory: {output_dir}")
    print()
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    for filename, size in ICON_SIZES:
        output_path = os.path.join(output_dir, filename)
        create_icon_with_background(source_icon, output_path, size)
    
    print()
    print("✅ All iOS icons generated successfully!")
    print()
    print("Next steps:")
    print("  1. Open Xcode")
    print("  2. Clean build folder (Cmd + Shift + K)")
    print("  3. Delete app from device/simulator")
    print("  4. Rebuild and run")

if __name__ == "__main__":
    main()
