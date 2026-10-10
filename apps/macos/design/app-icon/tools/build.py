"""Build Yatagarasu's app icons as Icon Composer packages.

    cd apps/macos/design/app-icon/tools
    uv run --no-project --with skia-python --with pillow --with numpy python build.py

Writes the app target's two icons and, when Xcode's ictool is available, preview renders:

    apps/macos/yatagarasu/Resources/AppIcon.icon        Classic (primary app icon)
    apps/macos/yatagarasu/Resources/PixelAppIcon.icon   Pixel (alternate, chosen in Settings)
    apps/macos/design/app-icon/previews/*.png
"""
import json
import os
import shutil
import subprocess
import tempfile

import crow
import pixel

HERE = os.path.dirname(os.path.abspath(__file__))
RESOURCES = os.path.normpath(os.path.join(HERE, "../../../yatagarasu/Resources"))
PREVIEWS = os.path.normpath(os.path.join(HERE, "../previews"))

# Where the vector character sits on the 1024 canvas.
CHARACTER_SCALE, CHARACTER_OFFSET_Y = 0.8, 22

SUNRISE_GRADIENT = ["srgb:1.00000,0.95294,0.86275,1.00000", "srgb:1.00000,0.81176,0.59608,1.00000"]
NIGHT_GRADIENT = ["srgb:0.18824,0.21961,0.49804,1.00000", "srgb:0.08235,0.09412,0.25098,1.00000"]
TOP_TO_BOTTOM = {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}}


def group(name, image, shadow="none", shadow_opacity=0.5):
    """One flat (non-glass) layer: the art stays crisp, the system still adds the icon's edge light."""
    layer = {"name": name, "glass": False, **image}
    return {
        "layers": [layer],
        "shadow": {"kind": shadow, "opacity": shadow_opacity},
        "specular": False,
        "translucency": {"enabled": False, "value": 0.5},
    }


def light_and_dark(light, dark):
    return {"image-name-specializations": [{"value": light}, {"appearance": "dark", "value": dark}]}


def write_icon(name, document, layers):
    path = os.path.join(RESOURCES, f"{name}.icon")
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(os.path.join(path, "Assets"))
    for filename, image in layers.items():
        image(os.path.join(path, "Assets", filename))
    with open(os.path.join(path, "icon.json"), "w") as f:
        json.dump(document, f, indent=2, sort_keys=True)
        f.write("\n")
    return path


def classic():
    character = crow.placed(crow.character_svg(sticker=True, sticker_width=18),
                            CHARACTER_SCALE, 0, CHARACTER_OFFSET_Y)
    return write_icon("AppIcon", {
        "fill-specializations": [
            {"value": {"linear-gradient": SUNRISE_GRADIENT, "orientation": TOP_TO_BOTTOM}},
            {"appearance": "dark", "value": {"linear-gradient": NIGHT_GRADIENT, "orientation": TOP_TO_BOTTOM}},
        ],
        "groups": [
            group("crow", {"image-name": "crow.png"}, shadow="neutral", shadow_opacity=0.35),
        ],
        "supported-platforms": {"squares": "shared"},
    }, {
        "crow.png": lambda out: crow.render(crow.svg_doc(character), out),
    })


def pixel_art():
    return write_icon("PixelAppIcon", {
        "fill-specializations": [
            {"value": {"solid": "srgb:1.00000,0.95294,0.86275,1.00000"}},
            {"appearance": "dark", "value": {"solid": "srgb:0.20392,0.23137,0.52549,1.00000"}},
        ],
        "groups": [
            group("crow", {"image-name": "crow.png"}),
            group("sky", light_and_dark("sky.png", "sky-dark.png")),
        ],
        "supported-platforms": {"squares": "shared"},
    }, {
        "crow.png": lambda out: pixel.character_layer().save(out),
        "sky.png": lambda out: pixel.background_layer().save(out),
        "sky-dark.png": lambda out: pixel.background_layer(bands=pixel.NIGHT).save(out),
    })


def previews(icons):
    """Render each icon as macOS draws it, using Icon Composer's ictool, into one sheet."""
    developer = subprocess.run(["xcode-select", "-p"], capture_output=True, text=True).stdout.strip()
    ictool = os.path.join(os.path.dirname(developer), "Applications/Icon Composer.app/Contents/Executables/ictool")
    if not os.access(ictool, os.X_OK):
        print("ictool not found; skipping previews")
        return
    from PIL import Image

    renditions = ["Default", "Dark", "TintedLight", "ClearLight"]
    tile, gap = 256, 24
    sheet = Image.new("RGBA", (gap + len(renditions) * (tile + gap), gap + len(icons) * (tile + gap)), (0, 0, 0, 0))
    os.makedirs(PREVIEWS, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for row, (name, path) in enumerate(icons.items()):
            for col, rendition in enumerate(renditions):
                out = os.path.join(tmp, f"{name}-{rendition}.png")
                subprocess.run([ictool, path, "--export-image", "--output-file", out, "--platform", "macOS",
                                "--rendition", rendition, "--width", "512", "--height", "512", "--scale", "2"],
                               check=True, capture_output=True)
                image = Image.open(out).convert("RGBA")
                if rendition == "Default":
                    image.save(os.path.join(PREVIEWS, f"{name}.png"))
                sheet.alpha_composite(image.resize((tile, tile), Image.LANCZOS),
                                      (gap + col * (tile + gap), gap + row * (tile + gap)))
    sheet.save(os.path.join(PREVIEWS, "appearances.png"))


if __name__ == "__main__":
    icons = {"classic": classic(), "pixel": pixel_art()}
    previews(icons)
    for name, path in icons.items():
        print(name, os.path.relpath(path))
