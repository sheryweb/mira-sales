from PIL import Image, ImageDraw
import os
import zipfile

out = r"c:\Salesforce-mira-sales\tmp-round-assets"
os.makedirs(out, exist_ok=True)

PAGE = (10, 22, 37, 255)  # #0A1625
CARD = (23, 38, 64, 255)  # #172640
BORDER = (36, 52, 79, 255)  # #24344F
PERIOD = (22, 35, 58, 255)  # #16233A
PERIOD_BORDER = (56, 189, 248, 255)  # #38BDF8


def hex_rgba(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) + (255,)


def save(img, name):
    path = os.path.join(out, name)
    img.save(path, "PNG")
    print("wrote", name, img.size)


def pill_caps(name, color, h=18, r=9):
    color = hex_rgba(color) if isinstance(color, str) else color
    for side in ("L", "R"):
        img = Image.new("RGBA", (r, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        if side == "L":
            d.ellipse((-r, 0, r, h - 1), fill=color)
        else:
            d.ellipse((0, 0, 2 * r, h - 1), fill=color)
        save(img, f"pill_{name}_{side}.png")


def corner_tile(fill, border, page, r, corner, border_w=1):
    img = Image.new("RGBA", (r, r), (0, 0, 0, 0))
    px = img.load()
    if corner == "tl":
        cx, cy = r - 0.5, r - 0.5
    elif corner == "tr":
        cx, cy = 0.5, r - 0.5
    elif corner == "bl":
        cx, cy = r - 0.5, 0.5
    else:
        cx, cy = 0.5, 0.5

    outer = r - 0.5
    inner = outer - border_w
    for y in range(r):
        for x in range(r):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist <= inner:
                px[x, y] = fill
            elif dist <= outer:
                px[x, y] = border
            else:
                px[x, y] = page
    return img


def make_card_corners(prefix, fill, border, page, r=12):
    for c in ("tl", "tr", "bl", "br"):
        save(corner_tile(fill, border, page, r, c), f"{prefix}_{c}.png")


def period_caps(h=48, r=14):
    fill, border = PERIOD, PERIOD_BORDER
    for side in ("L", "R"):
        img = Image.new("RGBA", (r, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        if side == "L":
            d.ellipse((-r, 0, r, h - 1), fill=border)
            d.ellipse((-r + 2, 2, r - 2, h - 3), fill=fill)
        else:
            d.ellipse((0, 0, 2 * r, h - 1), fill=border)
            d.ellipse((2, 2, 2 * r - 2, h - 3), fill=fill)
        save(img, f"period_{side}.png")


pill_caps("green", "#064E3B")
pill_caps("amber", "#78350F")
pill_caps("gray", "#1F2937")
pill_caps("purple", "#4C1D95")
period_caps()
make_card_corners("card", CARD, BORDER, PAGE, r=12)

zip_path = r"c:\Salesforce-mira-sales\force-app\main\default\staticresources\MonthlySalesReportRound.resource"
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for fn in sorted(os.listdir(out)):
        if fn.endswith(".png"):
            z.write(os.path.join(out, fn), fn)
print("zipped", zip_path)
