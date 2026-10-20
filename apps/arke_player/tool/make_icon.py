"""Makes the launcher and notification icons from the Arke icon. Needs Pillow.

    python apps/arke_player/tool/make_icon.py [--preview DIR]

The source, assets/icon/arke-512.png, is ArkeStudio's packages/client/public/icons/arke-512.png
copied as it is: the white A and amber arc on a black rounded tile, on a grey surround. A launcher
masks an icon to its own shape (a circle, One UI's squircle), so the tile is not used as drawn on
Android 8 and later: the mark is lifted off its black and set on a background of the same black,
inside the mask's safe zone. iOS rounds its own corners, so it gets the tile's black full bleed.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..')
SOURCE = os.path.join(APP, 'assets', 'icon', 'arke-512.png')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
IOS = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
# The tile's own black, sampled away from the mark.
BACKGROUND = (3, 3, 3)
# An adaptive icon is 108dp; a launcher may show only the circle of 66dp at its centre.
SAFE_RADIUS_DP = 31


def tile_mask(src):
    """The tile: everything a fill of the grey surround cannot reach from a corner."""
    probe = src.convert('RGB')
    ImageDraw.floodfill(probe, (0, 0), (255, 0, 255), thresh=12)
    return ImageChops.difference(probe, Image.new('RGB', src.size, (255, 0, 255))).convert('L').point(lambda v: 255 if v else 0)


def lift_mark(src, inside):
    """The mark alone, its black made clear: drawn over black, each pixel is alpha × colour."""
    rgb = src.convert('RGB')
    mark = Image.new('RGBA', src.size, (0, 0, 0, 0))
    for y in range(src.height):
        for x in range(src.width):
            if not inside.getpixel((x, y)):
                continue
            r, g, b = rgb.getpixel((x, y))
            a = max(r, g, b)
            # The tile's black is not quite zero, and lightens to 16 towards its lower edge: tile,
            # not mark. Left in, it drew a grey band under the mark.
            if a < 24:
                continue
            mark.putpixel((x, y), (r * 255 // a, g * 255 // a, b * 255 // a, a))
    return mark


def resize(image, size):
    # Premultiplied, so the clear pixels' colour does not bleed into the edges.
    return image.convert('RGBa').resize(size, Image.LANCZOS).convert('RGBA')


def centred(image, canvas, fill=(0, 0, 0, 0)):
    out = Image.new('RGBA', (canvas, canvas), fill)
    out.alpha_composite(image, ((canvas - image.width) // 2, (canvas - image.height) // 2))
    return out


def tinted(image, colour=(255, 255, 255)):
    out = Image.new('RGBA', image.size, colour + (0,))
    out.putalpha(image.getchannel('A'))
    return out


def main():
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    src = Image.open(SOURCE)
    tile = tile_mask(src)
    x0, y0, x1, y1 = tile.getbbox()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    # Inset past the tile's light rim, which is the tile's, not the mark's.
    mark = lift_mark(src, tile.filter(ImageFilter.MinFilter(21)))

    # The mark's reach from the tile's centre, counting only what reads at icon size.
    reach = max(
        math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        for y in range(mark.height)
        for x in range(mark.width)
        if mark.getpixel((x, y))[3] > 64
    )
    half = math.ceil(reach) + 4
    around = mark.crop((round(cx - half), round(cy - half), round(cx + half), round(cy + half)))
    solid = tinted(around)

    flat = Image.new('RGBA', src.size, (0, 0, 0, 0))
    flat.paste(src.convert('RGBA'), mask=tile)
    flat = flat.crop((x0, y0, x1, y1))

    for name, d in DENSITIES.items():
        folder = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(folder, exist_ok=True)
        canvas = round(108 * d)
        side = round(2 * half * SAFE_RADIUS_DP * d / reach)
        foreground = centred(resize(around, (side, side)), canvas)
        foreground.save(os.path.join(folder, 'ic_launcher_foreground.png'))
        tinted(foreground).save(os.path.join(folder, 'ic_launcher_monochrome.png'))
        # Before Android 8 the launcher shows the file as it is: the tile, its corners clear.
        centred(resize(flat, (round(46 * d), round(46 * d))), round(48 * d)).save(os.path.join(folder, 'ic_launcher.png'))

        # The status bar draws a notification icon's alpha in white; 24dp, the mark in 22.
        drawable = os.path.join(RES, f'drawable-{name}')
        os.makedirs(drawable, exist_ok=True)
        box = solid.getbbox()
        trimmed = solid.crop(box)
        fit = 22 * d / max(trimmed.size)
        small = resize(trimmed, (max(1, round(trimmed.width * fit)), max(1, round(trimmed.height * fit))))
        # The arc's glow fades to nothing at this size; what is left is drawn solid.
        small.putalpha(small.getchannel('A').point(lambda v: 0 if v < 48 else min(255, v * 3 // 2)))
        centred(small, round(24 * d)).save(os.path.join(drawable, 'ic_stat_arke.png'))

    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Made by tool/make_icon.py. -->\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
            '</adaptive-icon>\n'
        )
    with open(os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Made by tool/make_icon.py: the Arke tile\'s black. -->\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
            '</resources>\n' % BACKGROUND
        )

    # iOS: the tile full bleed, the mark where the tile has it; every size the template ships.
    square = Image.new('RGBA', (x1 - x0, y1 - y0), BACKGROUND + (255,))
    square.alpha_composite(mark.crop((x0, y0, x1, y1)))
    for name in sorted(os.listdir(IOS)):
        if name.endswith('.png'):
            path = os.path.join(IOS, name)
            size = Image.open(path).size
            # App Store icons may carry no alpha.
            resize(square, size).convert('RGB').save(path)

    if preview:
        os.makedirs(preview, exist_ok=True)
        full = 432
        layered = Image.new('RGBA', (full, full), BACKGROUND + (255,))
        layered.alpha_composite(Image.open(os.path.join(RES, 'mipmap-xxxhdpi', 'ic_launcher_foreground.png')))
        # What a launcher shows: the middle 72dp of 108, masked.
        view = layered.crop((72, 72, 360, 360))
        sheet = Image.new('RGBA', (288 * 4 + 50, 288 + 20), (236, 236, 240, 255))
        for i, shape in enumerate(['circle', 'squircle', 'ios', 'notification']):
            m = Image.new('L', (288, 288), 0)
            draw = ImageDraw.Draw(m)
            if shape == 'circle':
                draw.ellipse((0, 0, 287, 287), fill=255)
                tile_view = view
            elif shape == 'squircle':
                draw.rounded_rectangle((0, 0, 287, 287), radius=96, fill=255)
                tile_view = view
            elif shape == 'ios':
                draw.rounded_rectangle((0, 0, 287, 287), radius=64, fill=255)
                tile_view = resize(square, (288, 288))
            else:
                m = Image.new('L', (288, 288), 255)
                stat = Image.open(os.path.join(RES, 'drawable-xxxhdpi', 'ic_stat_arke.png'))
                tile_view = centred(resize(stat, (192, 192)), 288, (40, 44, 52, 255))
            cell = Image.new('RGBA', (288, 288), (0, 0, 0, 0))
            cell.paste(tile_view, mask=m)
            sheet.alpha_composite(cell, (10 + i * 298, 10))
        sheet.save(os.path.join(preview, 'icons.png'))


main()
