from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

assets = Path(r"C:\mywork\assets")
assets.mkdir(parents=True, exist_ok=True)

ico_path = assets / "qda.ico"
png_path = assets / "qda.png"

size = 256
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Nen xanh
draw.rounded_rectangle(
    [16, 16, size - 16, size - 16],
    radius=52,
    fill=(37, 99, 235, 255)
)

# Chu Q
try:
    font = ImageFont.truetype("arialbd.ttf", 138)
except:
    font = ImageFont.load_default()

text = "Q"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]

x = (size - tw) / 2
y = (size - th) / 2 - 8

draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

img.save(png_path)

img.save(
    ico_path,
    format="ICO",
    sizes=[
        (16, 16),
        (24, 24),
        (32, 32),
        (48, 48),
        (64, 64),
        (128, 128),
        (256, 256),
    ],
)

print("Da tao icon:")
print(ico_path)