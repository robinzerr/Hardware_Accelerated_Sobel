#!/usr/bin/env bash
#-------------------------------------------------------------------------------
# run_ghdl.sh -- free local simulation with GHDL (no Vivado needed).
# Reproduces exactly what the Vivado XSim flow does.
#
# USAGE:
#   ./run_ghdl.sh <image_file> <width> <height>
# EXAMPLE:
#   ./run_ghdl.sh model/test.png 32 32
#
# Requires: ghdl, python3 with pillow + numpy.
#-------------------------------------------------------------------------------
set -e

IMG=${1:-model/test.png}
W=${2:-32}
H=${3:-32}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ">> Converting $IMG -> sim/input_pixels.txt ($W x $H)"
python3 scripts/img_to_txt.py "$IMG" sim/input_pixels.txt --width "$W" --height "$H"

cd sim
echo ">> Analyzing VHDL sources"
ghdl -a --std=08 -fsynopsys \
    ../rtl/line_buffer.vhd \
    ../rtl/window_former.vhd \
    ../rtl/sobel_core.vhd \
    ../rtl/sobel_top.vhd \
    tb_sobel_top.vhd

echo ">> Elaborating"
ghdl -e --std=08 -fsynopsys tb_sobel_top

echo ">> Running simulation"
rm -f output_pixels.txt
ghdl -r --std=08 -fsynopsys tb_sobel_top -gIMG_WIDTH="$W" -gIMG_HEIGHT="$H" \
    2>&1 | grep -E "Streamed|Captured|Expected" || true

cd ..
echo ">> Reconstructing image and computing metrics"
python3 scripts/txt_to_img.py "$IMG" sim/output_pixels.txt sim/result.png --width "$W" --height "$H"

echo ">> Done. See sim/result.png, sim/result_golden.png, sim/result_diff.png"
