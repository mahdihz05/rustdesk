"""Generate platform icon resources from the supplied Abrit logo."""
import argparse
import base64
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def save_png(image, relative, size, opaque=False):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    output = image.resize((size, size), Image.Resampling.LANCZOS)
    if opaque:
        background = Image.new("RGB", output.size, "#0071ff")
        background.paste(output, mask=output.getchannel("A"))
        output = background
    output.save(target)


def generate(logo=None, monochrome_logo=None):
    if not logo:
        logo = ROOT / 'res/abrit/logo-source.jpg'
    source = Image.open(logo).convert('RGBA')
    # The supplied JPEG uses white paper around the blue wordmark.
    pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, a = pixels[x, y]
            if r > 220 and g > 220 and b > 220:
                pixels[x, y] = (r, g, b, 0)
    source = source.crop(source.getbbox())
    source.save(ROOT / 'flutter/assets/abrit/wordmark.png')
    # Use the supplied cloud mark for small app/tray icons; keep the full
    # wordmark and tagline, with their original proportions, in the UI.
    mark = source.crop((0, 0, source.width, round(source.height * .78)))
    image = Image.new('RGBA', (1024, 1024))
    mark.thumbnail((944, 944), Image.Resampling.LANCZOS)
    image.paste(mark, ((1024 - mark.width) // 2,
                      (1024 - mark.height) // 2), mark)
    save_png(image, "flutter/assets/abrit/logo.png", 256)
    save_png(image, "flutter/assets/icon.png", 256)
    encoded = base64.b64encode((ROOT / "flutter/assets/abrit/logo.png").read_bytes()).decode()
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
           f'<image width="100" height="100" href="data:image/png;base64,{encoded}"/></svg>')
    for relative in ["res/scalable.svg", "res/logo.svg", "flutter/assets/icon.svg", "flutter/assets/abrit/logo.svg"]:
        (ROOT / relative).write_text(svg, encoding="utf-8")
    header = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 310 80">'
              f'<image x="4" y="8" width="64" height="64" href="data:image/png;base64,{encoded}"/>'
              '<text x="84" y="48" font-family="sans-serif" font-size="27" '
              'font-weight="bold" fill="#0071ff">abritdesk</text></svg>')
    (ROOT / "res/logo-header.svg").write_text(header, encoding="utf-8")
    for name, size in [("icon.png", 256), ("mac-icon.png", 1024),
                       ("32x32.png", 32), ("64x64.png", 64),
                       ("128x128.png", 128), ("128x128@2x.png", 256)]:
        save_png(image, "res/" + name, size)
    for relative in ["res/icon.ico", "res/tray-icon.ico",
                     "flutter/assets/icon.ico",
                     "flutter/windows/runner/resources/app_icon.ico"]:
        target = ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        image.resize((256, 256)).save(target, sizes=[(16, 16), (24, 24),
            (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    image.resize((1024, 1024)).save(ROOT / "flutter/macos/Runner/AppIcon.icns")
    template = Image.new("RGBA", (64, 64))
    if monochrome_logo:
        alpha = Image.open(monochrome_logo).convert("RGBA").resize((64, 64)).getchannel("A")
        template.paste("white", mask=alpha)
    else:
        template.paste('white', mask=image.resize((64, 64), Image.Resampling.LANCZOS).getchannel('A'))
    for name in ["mac-tray-dark-x2.png", "mac-tray-light-x2.png"]:
        template.save(ROOT / "res" / name)
    for density, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)]:
        directory = "flutter/android/app/src/main/res/mipmap-" + density + "/"
        for name in ["ic_launcher.png", "ic_launcher_round.png"]:
            save_png(image, directory + name, size)
        adaptive_size = round(size * 2.25)
        foreground = Image.new("RGBA", (adaptive_size, adaptive_size))
        mark_size = round(adaptive_size * 2 / 3)
        mark = image.resize((mark_size, mark_size), Image.Resampling.LANCZOS)
        inset = (adaptive_size - mark_size) // 2
        foreground.paste(mark, (inset, inset), mark)
        foreground.save(ROOT / (directory + "ic_launcher_foreground.png"))
        save_png(template, directory + "ic_stat_logo.png", max(24, size // 2))
    ios = ROOT / "flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    content = json.loads((ios / "Contents.json").read_text(encoding="utf-8"))
    for entry in content["images"]:
        if "filename" in entry:
            size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
            save_png(image, str((ios / entry["filename"]).relative_to(ROOT)), size, opaque=True)
    print("Generated abritdesk icon resources; technical identifiers unchanged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logo", type=Path)
    parser.add_argument("--monochrome-logo", type=Path,
        help="Transparent silhouette for tray and notification icons.")
    args = parser.parse_args()
    generate(args.logo, args.monochrome_logo)
