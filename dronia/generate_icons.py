#!/usr/bin/env python3
"""Generate all app icons from Icone.png for Android and iOS"""
from PIL import Image
import os

src = "assets/images/Logo_DronIA-11.png"
img = Image.open(src).convert("RGBA")
img_rgb = img.convert("RGB")
res_dir = "android/app/src/main/res"

# 1. Android mipmap icons
for folder, size in [("mipmap-mdpi",48),("mipmap-hdpi",72),("mipmap-xhdpi",96),("mipmap-xxhdpi",144),("mipmap-xxxhdpi",192)]:
    out = os.path.join(res_dir, folder, "ic_launcher.png")
    img.resize((size, size), Image.LANCZOS).save(out)
    print(f"  OK {out} ({size}x{size})")

# 2. Android adaptive foreground
for folder, size in [("drawable-mdpi",108),("drawable-hdpi",162),("drawable-xhdpi",216),("drawable-xxhdpi",324),("drawable-xxxhdpi",432)]:
    out_dir = os.path.join(res_dir, folder)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "ic_launcher_foreground.png")
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon_size = int(size * 0.82)
    icon_resized = img.resize((icon_size, icon_size), Image.LANCZOS)
    offset = (size - icon_size) // 2
    canvas.paste(icon_resized, (offset, offset), icon_resized)
    canvas.save(out)
    print(f"  OK {out} ({size}x{size})")

# 3. iOS icons
ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for filename, size in [
    ("Icon-App-20x20@1x.png",20),("Icon-App-20x20@2x.png",40),("Icon-App-20x20@3x.png",60),
    ("Icon-App-29x29@1x.png",29),("Icon-App-29x29@2x.png",58),("Icon-App-29x29@3x.png",87),
    ("Icon-App-40x40@1x.png",40),("Icon-App-40x40@2x.png",80),("Icon-App-40x40@3x.png",120),
    ("Icon-App-50x50@1x.png",50),("Icon-App-50x50@2x.png",100),
    ("Icon-App-57x57@1x.png",57),("Icon-App-57x57@2x.png",114),
    ("Icon-App-60x60@2x.png",120),("Icon-App-60x60@3x.png",180),
    ("Icon-App-72x72@1x.png",72),("Icon-App-72x72@2x.png",144),
    ("Icon-App-76x76@1x.png",76),("Icon-App-76x76@2x.png",152),
    ("Icon-App-83.5x83.5@2x.png",167),
    ("Icon-App-1024x1024@1x.png",1024),
]:
    out = os.path.join(ios_dir, filename)
    img_rgb.resize((size, size), Image.LANCZOS).save(out)
    print(f"  OK {out} ({size}x{size})")

# 4. Play Store icon 512x512
img_rgb.resize((512, 512), Image.LANCZOS).save("assets/images/playstore_icon.png")
print("  OK assets/images/playstore_icon.png (512x512)")

print("\nDone! All icons generated.")
