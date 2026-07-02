# Pipelined RTL Sobel Edge-Detection Accelerator

Hierarchical VHDL implementation of the pipelined 3x3 Sobel accelerator from the
ENGR 446 reports, with a file-based testbench for **simulation only** (Vivado
XSim or GHDL - no board required). You feed in an image, the RTL filters it one
pixel per clock, and you evaluate the edge output and verification metrics on the
other side against a software golden model.

## Module hierarchy

```
sobel_top                      top level, streaming pixel interface
|-- window_former              assembles the 3x3 window from the raster stream
|   |-- line_buffer  (lb0)     one-row delay (infers BRAM)
|   |-- line_buffer  (lb1)     second one-row delay
|-- sobel_core                 2-stage arithmetic pipeline: Gx, Gy, |Gx|+|Gy|, saturate
```

| File | Role |
|------|------|
| `rtl/line_buffer.vhd`   | Single image-row buffer; synchronous read-first RAM (BRAM-inferable). |
| `rtl/window_former.vhd` | Two line buffers + three shift registers form the 3x3 window; tracks validity and excludes image borders. |
| `rtl/sobel_core.vhd`    | Computes Gx, Gy with adders/subtractors/shifts (no multipliers), then M = |Gx| + |Gy| saturated to 8 bits. 2 pipeline stages. |
| `rtl/sobel_top.vhd`     | Wires the two together and exposes in_valid/in_pixel -> out_valid/out_pixel. |
| `sim/tb_sobel_top.vhd`  | File-driven testbench: reads input_pixels.txt, streams it, writes output_pixels.txt. |

## Streaming interface (sobel_top)

| Port | Dir | Meaning |
|------|-----|---------|
| clk       | in  | clock (testbench uses 100 MHz / 10 ns) |
| rst       | in  | synchronous, active-high reset |
| in_valid  | in  | assert when a new pixel is on in_pixel |
| in_pixel  | in  | 8-bit grayscale pixel, raster order (row by row, left to right) |
| out_valid | out | high when out_pixel is a valid interior edge pixel |
| out_pixel | out | 8-bit edge magnitude |

Generics: DATA_WIDTH (8), IMG_WIDTH, IMG_HEIGHT. Because border pixels have no
full 3x3 neighbourhood, the output image is **(WIDTH-2) x (HEIGHT-2)**. The
Python helper handles this framing automatically.

## How images get in and out

Vivado's simulator cannot open a PNG directly, so images are passed as plain
**text files of pixel values** (one decimal 0-255 per line, raster order) using
std.textio. Two Python helpers do the conversion:

- `scripts/img_to_txt.py` - PNG/JPG -> input_pixels.txt (grayscale, optional resize)
- `scripts/txt_to_img.py` - output_pixels.txt -> result.png, and compares vs golden model

Both need: pip install pillow numpy

## Quick start - GHDL (free, no Vivado)

```bash
./run_ghdl.sh model/test.png 32 32
```

That converts the image, simulates, reconstructs sim/result.png, and prints
metrics. On the bundled test images it reports **100% exact match** vs the golden
model (the RTL uses identical integer arithmetic, so any error would be a real bug).

## Quick start - Vivado (simulation only)

1. Convert your image and note the printed width/height:
   ```
   python scripts/img_to_txt.py my_image.png sim/input_pixels.txt
   ```
2. Edit run_vivado_sim.tcl and set IMG_W / IMG_H to those values.
3. Run:
   ```
   vivado -mode batch -source run_vivado_sim.tcl
   ```
   (or `source run_vivado_sim.tcl` in the Vivado Tcl console).
4. Reconstruct and evaluate:
   ```
   python scripts/txt_to_img.py my_image.png sim/output_pixels.txt result.png --width W --height H
   ```

To use the Vivado GUI instead: create a project, add the four rtl/*.vhd files and
sim/tb_sobel_top.vhd, set tb_sobel_top as the simulation top, set the
IMG_WIDTH/IMG_HEIGHT generics on sim_1, put input_pixels.txt in the sim run
directory (<proj>.sim/sim_1/behav/xsim/), and Run Behavioral Simulation. Add
out_valid, out_pixel, and the window signals to the waveform to capture the
simulation screenshots your report asks for.

## Metrics you get

txt_to_img.py prints, and saves images for:

- **Exact-match %** - fraction of output pixels bit-identical to the golden model
- **Max / mean absolute error**
- **PSNR** (dB; infinite on an exact match)
- result.png (RTL output), result_golden.png (reference), result_diff.png

## Notes for the report

- The design avoids DSP multipliers: coefficients +/-1, +/-2 map to adds/subtracts
  and a shift-left-by-one, so DSP usage should synthesize to ~0.
- line_buffer is written to infer BRAM; the two buffers dominate memory usage.
- Latency is about 2*WIDTH + a few cycles (line-buffer fill) + 2 (arithmetic
  pipeline). Steady-state throughput is one output pixel per clock.
- For a full 640x480 frame, set the generics to 640/480. Simulation time scales
  with pixel count, so start small (32x32, 64x64) while bringing the flow up.

## Tips

- Keep IMG_WIDTH/IMG_HEIGHT (generics) equal to the width/height you passed to
  img_to_txt.py, or the framing will be wrong.
- If output_pixels.txt looks empty, make sure no stale, read-only copy exists in
  the sim working directory, and let the simulation run to completion (run -all)
  so the file is flushed and closed.
