# Handover — Sobel VHDL Accelerator Project

**For:** next Claude session (running sims locally on Rob's laptop)
**From:** Cowork session, 2026-07-03
**Repo:** https://github.com/robinzerr/Hardware_Accelerated_Sobel

## Project state: WORKING — all sims pass

The full GHDL simulation flow was run end-to-end in a Linux sandbox on
2026-07-03. Nothing in the RTL or scripts needed fixing. The design is verified
at 4 image sizes with 100% exact match vs the software golden model.

## What the project is

Pipelined 3x3 Sobel edge-detection accelerator in VHDL (ENGR 446 reports).
Simulation-only (GHDL or Vivado XSim, no board). See `sobel/README.md` for
module hierarchy and flow details.

- `sobel/rtl/` — line_buffer, window_former, sobel_core, sobel_top
- `sobel/sim/tb_sobel_top.vhd` — file-driven TB (input_pixels.txt → output_pixels.txt)
- `sobel/scripts/` — img_to_txt.py / txt_to_img.py (PNG ↔ text, computes metrics)
- `sobel/run_ghdl.sh` — one-command flow: convert → analyze → elaborate → run → metrics
- `sobel/results/` — verified outputs + `METRICS.md` (all report numbers, already filled in)

## Verified results (fill reports from `sobel/results/METRICS.md`)

| Run | Frame | Output | Exact match | Max/mean err | PSNR |
|-----|-------|--------|-------------|--------------|------|
| test.png | 32x32 | 30x30 (900 px) | 100.0000% | 0 / 0.0000 | inf dB |
| photo.png | 48x48 | 46x46 (2,116 px) | 100.0000% | 0 / 0.0000 | inf dB |
| photo.png | 256x256 | 254x254 (64,516 px) | 100.0000% | 0 / 0.0000 | inf dB |
| photo.png | 640x480 | 638x478 (304,964 px) | 100.0000% | 0 / 0.0000 | inf dB |

Performance (measured @ 100 MHz TB clock, 640x480 run):
- Latency: **1,285 cycles = 12.85 µs** first-in → first-out. Matches theory 2·W+5
  (2 line-buffer rows 1,280 + window 3 + 2-stage arithmetic pipeline).
- Throughput: 1 pixel/clock steady state = 100 Mpixel/s; full frame ≈ 3.085 ms ≈ 324 fps.
- Total simulated time full frame: 3,085,165 ns.
- No DSPs (shift-add only); memory = two row-buffer BRAMs.

100% match is EXPECTED (RTL and golden model use identical integer math) —
any mismatch means a real bug, not noise.

## How to run on the laptop

Windows options, easiest first:
1. **MSYS2/standalone GHDL for Windows** — GHDL releases ship
   `ghdl-mcode-*-mingw64.zip` / `ucrt64.zip` (standalone). Unzip, add `bin` to
   PATH. Then run the steps from `run_ghdl.sh` manually (it's a bash script;
   on Windows run the same commands in PowerShell, or use Git Bash to run the
   script as-is).
2. **WSL** — `sudo apt install ghdl`, then `./run_ghdl.sh model/photo.png 640 480`.
3. **Vivado XSim** — use `run_vivado_sim.tcl` (set IMG_W/IMG_H inside it first);
   good for the waveform screenshots the report asks for.

Python needs: `pip install pillow numpy`.

Command that reproduces the headline run:
```
./run_ghdl.sh model/photo.png 640 480
```
GHDL flags used (already in the script): `--std=08 -fsynopsys`. Verified with
GHDL 1.0.0 mcode; newer versions fine.

## Gotchas learned this session

- **Framing:** IMG_WIDTH/IMG_HEIGHT generics must equal the size passed to
  img_to_txt.py or output framing is wrong. Output is always (W-2)x(H-2).
- **Empty output_pixels.txt:** let the sim run to completion so textio flushes;
  delete stale copies in the sim dir first.
- **640x480 sim wall time:** ~40 s with GHDL mcode. Sizes 256x256 and below are
  a few seconds. Sim time scales linearly with pixel count.
- **Latency measurement:** stock TB doesn't report it. This session patched the
  TB (temporarily) to record `now` at the first out_valid — first output at
  12,895 ns with first pixel clocked in at 45 ns → 1,285 cycles. Re-patch the
  same way if you need to re-measure (add a `first_t : time` variable set in
  the capture procedure when ocount = 0).
- The two big rectangles in photo.png produce clean bright outlines in
  result.png; result_diff.png should be pure black (zero error).

## Remaining / optional work

- Vivado waveform screenshots for the report (out_valid, out_pixel, window
  signals) — needs the Vivado GUI, wasn't possible in the sandbox.
- Synthesis resource/timing numbers (LUT/FF/BRAM/DSP counts, Fmax) if the
  report wants them — needs Vivado synth; expectation: 0 DSPs, 2 BRAMs
  dominating, comfortably meets 100 MHz.
- Everything else (functional verification + performance metrics) is done and
  recorded in `sobel/results/METRICS.md`.
