#!/usr/bin/env python3
"""
img_to_txt.py -- convert an image to a grayscale pixel text file for the VHDL TB.

Usage:
    python img_to_txt.py input.png input_pixels.txt [--width W --height H]

- Loads the image, converts to 8-bit grayscale.
- Optionally resizes to WxH (defaults to keeping the image's own size; you MUST
  then set the testbench IMG_WIDTH/IMG_HEIGHT generics to match).
- Writes one decimal pixel (0..255) per line, in raster order (row-major).

Requires: pillow, numpy   ->   pip install pillow numpy
"""
import argparse
import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("out_txt")
    ap.add_argument("--width", type=int, default=None)
    ap.add_argument("--height", type=int, default=None)
    args = ap.parse_args()

    img = Image.open(args.image).convert("L")  # 8-bit grayscale
    if args.width and args.height:
        img = img.resize((args.width, args.height), Image.BILINEAR)

    arr = np.asarray(img, dtype=np.uint8)
    h, w = arr.shape
    with open(args.out_txt, "w") as f:
        for r in range(h):
            for c in range(w):
                f.write(f"{int(arr[r, c])}\n")

    print(f"Wrote {w}x{h} = {w*h} pixels to {args.out_txt}")
    print(f"Set testbench generics: IMG_WIDTH={w}  IMG_HEIGHT={h}")


if __name__ == "__main__":
    main()
