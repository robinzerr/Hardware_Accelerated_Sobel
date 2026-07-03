Converted images for simulation
================================

Each image has a grayscale PNG (full resolution) and a ready-to-use
input_pixels.txt at a sim-friendly size (128 wide, aspect preserved).

Image          | txt file                      | IMG_WIDTH | IMG_HEIGHT
---------------|-------------------------------|-----------|-----------
harry_potter   | harry_potter_input_pixels.txt |    128    |    228
rimac_car      | rimac_car_input_pixels.txt    |    128    |     72
worldcup       | worldcup_input_pixels.txt     |    128    |     85

To simulate (Vivado):
1. Copy the chosen *_input_pixels.txt into the xsim working directory,
   RENAMED to input_pixels.txt
2. Set IMG_W / IMG_H in run_vivado_sim.tcl (or the sim_1 generics in the GUI)
   to the values in the table above
3. Run the sim, then reconstruct:
   python scripts/txt_to_img.py Images/converted/<name>.png sim/output_pixels.txt result.png --width <W> --height <H>

For a different resolution, regenerate any size with:
   python scripts/img_to_txt.py Images/converted/<name>.png sim/input_pixels.txt --width W --height H
(128-wide keeps XSim runtime reasonable; GHDL handles much larger easily.)
