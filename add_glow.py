from PIL import Image, ImageFilter, ImageChops, ImageEnhance

src = Image.open('/Users/kim/SlowRide/assets/logga_nobg.png').convert('RGBA')
w, h = src.size  # 800 x 674

alpha = src.split()[3]

# ── 1. GLOW on white/bright parts (full alpha binary mask) ───────────────
binary = alpha.point(lambda p: 255 if p > 10 else 0)

glow_color = (200, 230, 255, 255)
colored = Image.new('RGBA', (w, h), glow_color)

spread1 = binary.filter(ImageFilter.GaussianBlur(radius=26))
spread2 = binary.filter(ImageFilter.GaussianBlur(radius=12))
spread = ImageChops.add(spread1, spread2)
glow_mask = ImageChops.subtract(spread, binary)

# ── 2. VERTICAL FADE: full glow top, fades to ~30% at bottom of triangle ─
# The triangle bottom tip is around y=73%. Below that: text zone → no glow.
fade = Image.new('L', (w, h), 255)
fade_data = fade.load()
fade_start = int(h * 0.55)   # start fading here
fade_end   = int(h * 0.76)   # fully gone here (just above text)

for y in range(fade_start, h):
    if y >= fade_end:
        val = 0
    else:
        val = int(255 * (1.0 - (y - fade_start) / (fade_end - fade_start)))
    for x in range(w):
        fade_data[x, y] = val

# Apply fade to glow mask
glow_mask = ImageChops.multiply(glow_mask, fade)

glow_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
glow_layer.paste(colored, mask=glow_mask)

result = Image.alpha_composite(glow_layer, src)

# ── 3. BRIGHTEN TEXT ─────────────────────────────────────────────────────
text_y_start = int(h * 0.78)
text_region = result.crop((0, text_y_start, w, h))
tr, tg, tb, ta = text_region.split()
rgb = Image.merge('RGB', (tr, tg, tb))
rgb = ImageEnhance.Brightness(rgb).enhance(2.2)
rgb = ImageEnhance.Contrast(rgb).enhance(1.7)
bright_text = Image.merge('RGBA', (*rgb.split(), ta))
result.paste(bright_text, (0, text_y_start))

result.save('/Users/kim/SlowRide/assets/logga_nobg.png')
print(f'Done! {result.size}, {result.mode}')

glow_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
glow_layer.paste(colored, mask=glow_mask)

result = Image.alpha_composite(glow_layer, src)

# ── 2. BRIGHTEN TEXT: boost only the text rows (CruizX + NAVIGATION) ────
text_y_start = int(h * 0.78)

# Crop just the text region from the composited result
text_region = result.crop((0, text_y_start, w, h))
r, g, b, a = text_region.split()

# Boost RGB brightness by 1.5x (clamps at 255 automatically)
r = ImageEnhance.Brightness(r).enhance(1.5)
g = ImageEnhance.Brightness(g).enhance(1.5)
b = ImageEnhance.Brightness(b).enhance(1.5)

# Also increase contrast so edges are razor sharp
rgb = Image.merge('RGB', (r, g, b))
rgb = ImageEnhance.Contrast(rgb).enhance(1.4)

bright_text = Image.merge('RGBA', (*rgb.split(), a))
result.paste(bright_text, (0, text_y_start))

result.save('/Users/kim/SlowRide/assets/logga_nobg.png')
print(f'Done! {result.size}, {result.mode}')
