# Simulation Results — Pipelined Sobel Accelerator (GHDL 1.0.0, VHDL-2008)

All runs: file-driven testbench `tb_sobel_top`, 100 MHz clock (10 ns period),
one pixel streamed per clock, RTL output compared against the software golden
model in `scripts/txt_to_img.py`.

## Verification metrics (RTL vs golden model)

| Run | Input | Frame | Output frame | Output pixels | Exact match | Max abs err | Mean abs err | PSNR |
|-----|-------|-------|--------------|---------------|-------------|-------------|--------------|------|
| 1 | model/test.png  | 32x32   | 30x30   | 900     | 100.0000 % | 0 | 0.0000 | inf dB |
| 2 | model/photo.png | 48x48 (native) | 46x46 | 2,116 | 100.0000 % | 0 | 0.0000 | inf dB |
| 3 | model/photo.png | 256x256 | 254x254 | 64,516  | 100.0000 % | 0 | 0.0000 | inf dB |
| 4 | model/photo.png | 640x480 (full frame) | 638x478 | 304,964 | 100.0000 % | 0 | 0.0000 | inf dB |

Exact match of 100 % / PSNR = infinity is the expected result: the RTL and the
golden model use identical integer arithmetic, so any mismatch would indicate
a real RTL bug. None was found.

## Timing / performance (measured in simulation, 640x480 run)

- Clock frequency (testbench): 100 MHz (10 ns period)
- Pixels streamed in: 307,200 (all consumed, one per clock — no stalls)
- Output pixels captured: 304,964 = (640-2) x (478) interior pixels, exactly as expected
- **Pipeline latency (measured): 1,285 clock cycles = 12.85 us** from first
  pixel in to first valid pixel out. Matches theory: 2·IMG_WIDTH + 5
  (two line-buffer rows = 1,280, window formation = 3, sobel_core arithmetic
  pipeline = 2).
- **Throughput: 1 pixel/clock steady state** = 100 Mpixel/s at 100 MHz
- Full 640x480 frame time: 307,200 cycles + 1,285 latency ≈ 3.085 ms
  → ~324 frames/s at 100 MHz
- Total simulated time for full frame: 3,085,165 ns (matches testbench end-of-run report)

## Architecture notes for the report

- No DSP multipliers: Sobel coefficients ±1, ±2 implemented with
  add/subtract and shift-left-1 → DSP usage synthesizes to ~0.
- Memory: two line buffers (one image row each, 8 bit x IMG_WIDTH),
  written to infer BRAM; these dominate memory usage.
- Border handling: pixels without a full 3x3 neighbourhood are excluded,
  so output frame is (W-2) x (H-2).

## Result images

- `results/photo_640x480/` — result.png (RTL), result_golden.png (software
  reference), result_diff.png (difference: all black = zero error)
- `results/photo_48x48/` — same set for the native-resolution run

## Reproduction

```
./run_ghdl.sh model/photo.png 640 480
```
(GHDL 1.0.0, --std=08 -fsynopsys; Python 3 with pillow + numpy)
