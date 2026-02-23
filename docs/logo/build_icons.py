#!/usr/bin/env python3
"""
Crop extra padding from the logo and generate all macOS app icon sizes.
Outputs to doc/logo/ and to the app's AppIcon.appiconset.
"""
from pathlib import Path

from PIL import Image

# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
LOGO_PATH = SCRIPT_DIR / "logo.png"
OUT_DIR = SCRIPT_DIR  # doc/logo/
APPICON_DIR = SCRIPT_DIR.parent.parent / "copilot-island" / "Assets.xcassets" / "AppIcon.appiconset"

# macOS App Icon sizes (pt × scale = px): we need these pixel sizes
# 16@1x, 16@2x, 32@1x, 32@2x, 128@1x, 128@2x, 256@1x, 256@2x, 512@1x, 512@2x
SIZES_PX = [16, 32, 64, 128, 256, 512, 1024]


def get_content_bbox(im: Image.Image, alpha_thresh: int = 12, dark_thresh: int = 18) -> tuple[int, int, int, int]:
    """Bounding box of non-padding: alpha above thresh or color not nearly black."""
    w, h = im.size
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    data = im.load()
    x_min, y_min, x_max, y_max = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = data[x, y]
            is_content = a > alpha_thresh or max(r, g, b) > dark_thresh
            if is_content:
                x_min = min(x_min, x)
                y_min = min(y_min, y)
                x_max = max(x_max, x)
                y_max = max(y_max, y)
    if x_min > x_max or y_min > y_max:
        return 0, 0, w, h
    return x_min, y_min, x_max + 1, y_max + 1


def crop_to_content(im: Image.Image) -> Image.Image:
    """Crop to content bbox, then center in a square canvas (no extra padding)."""
    bbox = get_content_bbox(im)
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    side = max(cw, ch)
    if side == 0:
        return im
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    paste_x = (side - cw) // 2
    paste_y = (side - ch) // 2
    out.paste(cropped, (paste_x, paste_y))
    return out


def main() -> None:
    if not LOGO_PATH.exists():
        raise SystemExit(f"Logo not found: {LOGO_PATH}")

    im = Image.open(LOGO_PATH).convert("RGBA")
    trimmed = crop_to_content(im)
    # Use 1024 as base so we have one sharp master
    if trimmed.size[0] != 1024 or trimmed.size[1] != 1024:
        trimmed = trimmed.resize((1024, 1024), Image.Resampling.LANCZOS)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    APPICON_DIR.mkdir(parents=True, exist_ok=True)

    # Save cropped full-size in doc/logo
    trimmed.save(OUT_DIR / "logo_cropped_1024.png", "PNG")
    print(f"Saved cropped 1024: {OUT_DIR / 'logo_cropped_1024.png'}")

    # Generate each size; save in doc/logo and in AppIcon.appiconset with asset names
    asset_entries = []
    for size in SIZES_PX:
        resized = trimmed.resize((size, size), Image.Resampling.LANCZOS)
        name = f"icon_{size}.png"
        resized.save(OUT_DIR / name, "PNG")
        resized.save(APPICON_DIR / name, "PNG")
        print(f"  {size}x{size} -> {name}")

    # Build Contents.json entries with filenames (Xcode expects these names per size/scale)
    # Asset catalog: size in points, scale 1x or 2x → filename by pixel size
    size_scale_to_px = [
        ("16x16", "1x", 16, "icon_16x16.png"),
        ("16x16", "2x", 32, "icon_32x32.png"),   # 16pt@2x = 32px, we use icon_32x32
        ("32x32", "1x", 32, "icon_32x32.png"),
        ("32x32", "2x", 64, "icon_64x64.png"),
        ("128x128", "1x", 128, "icon_128x128.png"),
        ("128x128", "2x", 256, "icon_256x256.png"),
        ("256x256", "1x", 256, "icon_256x256.png"),
        ("256x256", "2x", 512, "icon_512x512.png"),
        ("512x512", "1x", 512, "icon_512x512.png"),
        ("512x512", "2x", 1024, "icon_1024x1024.png"),
    ]
    # We didn't create icon_16x16.png / icon_32x32.png etc by scale name; we created icon_16.png, icon_32.png...
    # So we need to either rename or map. Our SIZES_PX gave us icon_16.png, icon_32.png, ... icon_1024.png.
    # Xcode asset names are arbitrary; the important thing is size in pixels. So we can use icon_16.png for 16x16 1x,
    # icon_32.png for 16x16 2x and 32x32 1x, etc. Let me align: save as icon_16x16.png (16px), icon_16x16@2x.png (32px)...
    # Actually the simplest is to keep our filenames icon_16.png ... icon_1024.png and reference those. But then we need
    # two files for 32px (16@2x and 32@1x) - same file. So we can use one file for both. So in Contents.json we point
    # 16x16 1x -> icon_16.png, 16x16 2x -> icon_32.png, 32x32 1x -> icon_32.png, 32x32 2x -> icon_64.png, ...
    # We have icon_16.png, icon_32.png, ..., icon_1024.png. So filenames: icon_16.png, icon_32.png, icon_64.png, icon_128.png,
    # icon_256.png, icon_512.png, icon_1024.png. But we saved as icon_16.png? No - we saved as icon_{size}.png so icon_16.png,
    # icon_32.png, etc. Good.
    # So map: 16x16 1x -> icon_16.png, 16x16 2x -> icon_32.png, 32x32 1x -> icon_32.png, 32x32 2x -> icon_64.png, ...
    contents = {
        "images": [
            {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon_16.png"},
            {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon_32.png"},
            {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon_32.png"},
            {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon_64.png"},
            {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128.png"},
            {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_256.png"},
            {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256.png"},
            {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_512.png"},
            {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512.png"},
            {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_1024.png"},
        ],
        "info": {"author": "xcode", "version": 1},
    }

    import json
    with open(APPICON_DIR / "Contents.json", "w") as f:
        json.dump(contents, f, indent=2)

    # We saved icon_16.png ... icon_1024.png above; asset catalog expects those exact names
    for size in SIZES_PX:
        name = f"icon_{size}.png"
        if not (APPICON_DIR / name).exists():
            trimmed.resize((size, size), Image.Resampling.LANCZOS).save(APPICON_DIR / name, "PNG")
    print(f"Updated {APPICON_DIR / 'Contents.json'} and icon files in AppIcon.appiconset.")
    print("Done.")


if __name__ == "__main__":
    main()
