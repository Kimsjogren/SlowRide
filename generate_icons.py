from PIL import Image

# All required iOS icon sizes
SIZES = [
    ('Icon-App-1024x1024@1x.png', 1024),
    ('Icon-App-20x20@1x.png',       20),
    ('Icon-App-20x20@2x.png',       40),
    ('Icon-App-20x20@3x.png',       60),
    ('Icon-App-29x29@1x.png',       29),
    ('Icon-App-29x29@2x.png',       58),
    ('Icon-App-29x29@3x.png',       87),
    ('Icon-App-40x40@1x.png',       40),
    ('Icon-App-40x40@2x.png',       80),
    ('Icon-App-40x40@3x.png',      120),
    ('Icon-App-50x50@1x.png',       50),
    ('Icon-App-50x50@2x.png',      100),
    ('Icon-App-57x57@1x.png',       57),
    ('Icon-App-57x57@2x.png',      114),
    ('Icon-App-60x60@2x.png',      120),
    ('Icon-App-60x60@3x.png',      180),
    ('Icon-App-72x72@1x.png',       72),
    ('Icon-App-72x72@2x.png',      144),
    ('Icon-App-76x76@1x.png',       76),
    ('Icon-App-76x76@2x.png',      152),
    ('Icon-App-83.5x83.5@2x.png',  167),
]

# App's dark blue background
BG_COLOR = (13, 40, 120)

src = Image.open('/Users/kim/SlowRide/assets/logga_nobg.png').convert('RGBA')
sw, sh = src.size  # 800 x 674

out_dir = '/Users/kim/SlowRide/ios/Runner/Assets.xcassets/AppIcon.appiconset'

for filename, size in SIZES:
    # Create blue background
    bg = Image.new('RGB', (size, size), BG_COLOR)

    # Scale logo to fit with padding (85% of icon size)
    scale = (size * 0.85) / max(sw, sh)
    new_w = int(sw * scale)
    new_h = int(sh * scale)
    logo = src.resize((new_w, new_h), Image.LANCZOS)

    # Center on background
    x = (size - new_w) // 2
    y = (size - new_h) // 2
    bg.paste(logo, (x, y), logo)

    bg.save(f'{out_dir}/{filename}')
    print(f'  {filename}: {size}x{size}')

print('All icons generated!')
