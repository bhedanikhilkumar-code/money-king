from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSET_PATH = ROOT / 'assets' / 'branding' / 'app_icon.png'
RES_DIR = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
WEB_ICONS_DIR = ROOT / 'web' / 'icons'
WINDOWS_ICON = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
FAVICON = ROOT / 'web' / 'favicon.png'

ASSET_PATH.parent.mkdir(parents=True, exist_ok=True)

SIZE = 1024
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Soft shadow
shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.rounded_rectangle((96, 110, 928, 942), radius=210, fill=(9, 11, 18, 210))
shadow = shadow.filter(ImageFilter.GaussianBlur(28))
img.alpha_composite(shadow)

# Main card background
card = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
card_draw = ImageDraw.Draw(card)
card_draw.rounded_rectangle((90, 90, 934, 934), radius=210, fill=(17, 22, 31, 255))

# Gradient overlay
for y in range(90, 935):
    t = (y - 90) / (934 - 90)
    r = int(14 + (38 - 14) * t)
    g = int(18 + (32 - 18) * t)
    b = int(28 + (72 - 28) * t)
    a = int(210 - 35 * t)
    card_draw.line((90, y, 934, y), fill=(r, g, b, a), width=1)

# Accent glow
accent = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
accent_draw = ImageDraw.Draw(accent)
accent_draw.ellipse((250, 210, 790, 750), fill=(103, 80, 255, 55))
accent_draw.ellipse((300, 260, 740, 700), fill=(0, 209, 255, 28))
accent = accent.filter(ImageFilter.GaussianBlur(42))
card.alpha_composite(accent)

# Decorative bars
bars = [(330, 640, 410, 770), (455, 560, 535, 770), (580, 480, 660, 770)]
bar_colors = [(74, 222, 128, 180), (99, 102, 241, 180), (129, 140, 248, 180)]
for rect, color in zip(bars, bar_colors):
    card_draw.rounded_rectangle(rect, radius=28, fill=color)

# Monogram disk
card_draw.ellipse((226, 176, 798, 748), outline=(255, 255, 255, 18), width=6)

# Stylized M
m_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
m_draw = ImageDraw.Draw(m_layer)
m_points = [(306, 690), (398, 330), (512, 540), (626, 330), (718, 690)]
m_draw.line(m_points, fill=(243, 246, 255, 255), width=88, joint='curve')
#m inner glow
m_layer = m_layer.filter(ImageFilter.GaussianBlur(0.2))
card.alpha_composite(m_layer)

# Ledger line
card_draw.rounded_rectangle((300, 790, 724, 822), radius=16, fill=(138, 149, 255, 185))
card_draw.rounded_rectangle((300, 790, 540, 822), radius=16, fill=(255, 255, 255, 110))

# Highlight
highlight = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
h_draw = ImageDraw.Draw(highlight)
h_draw.rounded_rectangle((120, 110, 904, 320), radius=180, fill=(255, 255, 255, 18))
highlight = highlight.filter(ImageFilter.GaussianBlur(20))
card.alpha_composite(highlight)

img.alpha_composite(card)
ASSET_PATH.parent.mkdir(parents=True, exist_ok=True)
img.save(ASSET_PATH)

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

for folder, size in sizes.items():
    target_dir = RES_DIR / folder
    target_dir.mkdir(parents=True, exist_ok=True)
    square = img.resize((size, size), Image.LANCZOS)
    square.save(target_dir / 'ic_launcher.png')

    round_icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse((0, 0, size, size), fill=255)
    round_icon.paste(square, (0, 0), mask)
    round_icon.save(target_dir / 'ic_launcher_round.png')

# Store a simple full-res round preview too
round_preview = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
mask = Image.new('L', (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.ellipse((0, 0, SIZE, SIZE), fill=255)
round_preview.paste(img, (0, 0), mask)
round_preview.save(ASSET_PATH.parent / 'app_icon_round.png')

# Web assets
WEB_ICONS_DIR.mkdir(parents=True, exist_ok=True)
img.resize((192, 192), Image.LANCZOS).save(WEB_ICONS_DIR / 'Icon-192.png')
img.resize((512, 512), Image.LANCZOS).save(WEB_ICONS_DIR / 'Icon-512.png')
round_preview.resize((192, 192), Image.LANCZOS).save(WEB_ICONS_DIR / 'Icon-maskable-192.png')
round_preview.resize((512, 512), Image.LANCZOS).save(WEB_ICONS_DIR / 'Icon-maskable-512.png')
img.resize((64, 64), Image.LANCZOS).save(FAVICON)

# Windows icon
WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
img.save(WINDOWS_ICON, format='ICO', sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])

print(f'Generated icon assets at {ASSET_PATH}')
