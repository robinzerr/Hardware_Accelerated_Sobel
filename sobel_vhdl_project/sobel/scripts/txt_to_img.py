#!/usr/bin/env python3
"""
txt_to_img.py -- reconstruct the Sobel output image from the VHDL output text
file, compare against a software golden model, and report metrics.

Usage:
    python txt_to_img.py input.png output_pixels.txt result.png [--width W --height H]

What it does:
    1. Loads the ORIGINAL image (grayscale) to build the golden reference.
    2. Computes the golden Sobel edge map |Gx|+|Gy| (saturated to 255) on the
       interior (W-2)x(H-2) region -- exactly what the RTL produces.
    3. Reads the RTL output text (one decimal per line, raster order) into the
       same (W-2)x(H-2) frame.
    4. Compares RTL vs golden: exact-match %, max abs error, mean abs error,
       PSNR. Saves the RTL result and a golden image and a difference image.

Requires: pillow, numpy   ->   pip install pillow numpy
"""
import argparse
import numpy as np
from PIL import Image


def golden_sobel(gray):
    """Return interior (H-2)x(W-2) |Gx|+|Gy| saturated to 8 bits, matching RTL."""
    g = gray.astype(np.int32)
    h, w = g.shape
    # 3x3 windows over the interior
    p00 = g[0:h-2, 0:w-2]; p01 = g[0:h-2, 1:w-1]; p02 = g[0:h-2, 2:w]
    p10 = g[1:h-1, 0:w-2]; p11 = g[1:h-1, 1:w-1]; p12 = g[1:h-1, 2:w]
    p20 = g[2:h,   0:w-2]; p21 = g[2:h,   1:w-1]; p22 = g[2:h,   2:w]

    gx = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20)
    gy = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02)
    m = np.abs(gx) + np.abs(gy)
    m = np.clip(m, 0, 255).astype(np.uint8)
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("orig_image")
    ap.add_argument("out_txt")
    ap.add_argument("result_png")
    ap.add_argument("--width", type=int, default=None)
    ap.add_argument("--height", type=int, default=None)
    args = ap.parse_args()

    img = Image.open(args.orig_image).convert("L")
    if args.width and args.height:
        img = img.resize((args.width, args.height), Image.BILINEAR)
    gray = np.asarray(img, dtype=np.uint8)
    h, w = gray.shape

    golden = golden_sobel(gray)               # (h-2) x (w-2)
    exp_count = (h-2) * (w-2)

    vals = []
    with open(args.out_txt) as f:
        for line in f:
            line = line.strip()
            if line:
                vals.append(int(line))
    rtl = np.array(vals, dtype=np.int32)

    print(f"Interior frame: {w-2} x {h-2} = {exp_count} pixels expected")
    print(f"RTL produced:   {rtl.size} pixels")
    if rtl.size != exp_count:
        print("WARNING: pixel count mismatch. Check IMG_WIDTH/IMG_HEIGHT and drain time.")
        n = min(rtl.size, exp_count)
        rtl = rtl[:n]
        golden_flat = golden.flatten()[:n]
    else:
        golden_flat = golden.flatten()

    rtl_clip = np.clip(rtl, 0, 255).astype(np.uint8)

    # ---- Metrics ----
    diff = np.abs(rtl_clip.astype(np.int32) - golden_flat.astype(np.int32))
    exact = np.mean(diff == 0) * 100.0
    max_err = int(diff.max()) if diff.size else 0
    mean_err = float(diff.mean()) if diff.size else 0.0
    mse = float((diff.astype(np.float64) ** 2).mean()) if diff.size else 0.0
    psnr = float('inf') if mse == 0 else 10.0 * np.log10((255.0 ** 2) / mse)

    print("\n=== Verification: RTL output vs software golden model ===")
    print(f"  Exact-match pixels : {exact:.4f} %")
    print(f"  Max abs error      : {max_err}")
    print(f"  Mean abs error     : {mean_err:.4f}")
    print(f"  PSNR               : {psnr:.2f} dB")
    print("  (Exact match of 100% is expected: the RTL and golden model use identical integer arithmetic.)")

    # ---- Save images ----
    if rtl_clip.size == exp_count:
        rtl_img = rtl_clip.reshape((h-2, w-2))
        Image.fromarray(rtl_img, mode="L").save(args.result_png)
        Image.fromarray(golden, mode="L").save(args.result_png.replace(".png", "_golden.png"))
        d = np.abs(rtl_img.astype(np.int32) - golden.astype(np.int32)).astype(np.uint8)
        Image.fromarray(d, mode="L").save(args.result_png.replace(".png", "_diff.png"))
        print(f"\nSaved: {args.result_png}, *_golden.png, *_diff.png")


if __name__ == "__main__":
    main()
