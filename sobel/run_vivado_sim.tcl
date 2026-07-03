#-------------------------------------------------------------------------------
# run_vivado_sim.tcl
# Creates a Vivado project, adds the RTL + testbench, sets the image dimensions,
# and runs a behavioral simulation of the Sobel accelerator.
#
# USAGE (from the directory containing this script, with the rtl/ and sim/
# folders alongside it):
#
#   Batch (no GUI):
#     vivado -mode batch -source run_vivado_sim.tcl
#
#   Or from the Vivado Tcl console:
#     cd <this directory>
#     source run_vivado_sim.tcl
#
# BEFORE RUNNING:
#   1. Convert your image to sim/input_pixels.txt:
#        python scripts/img_to_txt.py my_image.png sim/input_pixels.txt
#      Note the printed WIDTH and HEIGHT.
#   2. Set IMG_W / IMG_H below to those values.
#   3. The testbench reads/writes files in the SIMULATION WORKING DIRECTORY.
#      This script copies input_pixels.txt there and copies output_pixels.txt
#      back out when the sim finishes.
#-------------------------------------------------------------------------------

# ---- USER SETTINGS --------------------------------------------------------
set PROJ_NAME   sobel_sim
set PART        xc7a35tcpg236-1   ;# Artix-7 (Basys3-class); any 7-series part is fine for sim
set IMG_W       32                ;# <-- set to your image width
set IMG_H       32                ;# <-- set to your image height
# ---------------------------------------------------------------------------

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set RTL_DIR    $SCRIPT_DIR/rtl
set SIM_DIR    $SCRIPT_DIR/sim
set PROJ_DIR   $SCRIPT_DIR/$PROJ_NAME

# Fresh project each run.
if {[file exists $PROJ_DIR]} { file delete -force $PROJ_DIR }
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# Add RTL sources.
add_files -norecurse [list \
    $RTL_DIR/line_buffer.vhd \
    $RTL_DIR/window_former.vhd \
    $RTL_DIR/sobel_core.vhd \
    $RTL_DIR/sobel_top.vhd ]
set_property file_type {VHDL} [get_files *.vhd]

# Add simulation source.
add_files -fileset sim_1 -norecurse $SIM_DIR/tb_sobel_top.vhd
set_property top tb_sobel_top [get_filesets sim_1]

# Pass the image dimensions to the testbench via generics.
set_property generic "IMG_WIDTH=$IMG_W IMG_HEIGHT=$IMG_H" [get_filesets sim_1]

# Make the input pixel file available in the sim working directory.
set XSIM_DIR $PROJ_DIR/$PROJ_NAME.sim/sim_1/behav/xsim
file mkdir $XSIM_DIR
file copy -force $SIM_DIR/input_pixels.txt $XSIM_DIR/input_pixels.txt

# Run behavioral simulation. run -all lets the TB finish (it self-terminates).
launch_simulation
run -all

# Copy the results back next to the sources.
if {[file exists $XSIM_DIR/output_pixels.txt]} {
    file copy -force $XSIM_DIR/output_pixels.txt $SIM_DIR/output_pixels.txt
    puts "SUCCESS: output written to $SIM_DIR/output_pixels.txt"
} else {
    puts "WARNING: output_pixels.txt not found in $XSIM_DIR"
}

puts "Simulation complete. Reconstruct/verify the image with:"
puts "  python scripts/txt_to_img.py <your_image> sim/output_pixels.txt result.png --width $IMG_W --height $IMG_H"
