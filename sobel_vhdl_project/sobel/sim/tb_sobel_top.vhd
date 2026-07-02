--------------------------------------------------------------------------------
-- tb_sobel_top.vhd
-- File-driven testbench for the pipelined Sobel accelerator.
--
-- FLOW:
--   1. Reads an input image from a plain-text file: one decimal pixel (0..255)
--      per line, in raster order (row by row, left to right). IMG_WIDTH x
--      IMG_HEIGHT must match the file.
--   2. Streams pixels into sobel_top, one per clock, with in_valid = '1'.
--   3. Captures every output pixel where out_valid = '1' and writes it, one
--      decimal value per line, to an output text file in raster order.
--   4. Because the DUT marks border pixels invalid, the output image is
--      (IMG_WIDTH-2) x (IMG_HEIGHT-2). The Python helper handles this framing.
--
-- IMPLEMENTATION NOTE:
--   Input driving AND output capture are done in ONE process. This guarantees
--   the output file is opened, written, and closed deterministically in the
--   correct order (a two-process producer/consumer split can race at end-of-sim
--   in some simulators and leave the output file unflushed).
--
-- FILE PATHS: relative paths resolve to the simulator working directory. In
-- Vivado that is typically <project>.sim/sim_1/behav/xsim/. Either place the
-- input file there, or set absolute paths via the generics.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_sobel_top is
    generic (
        DATA_WIDTH : integer := 8;
        IMG_WIDTH  : integer := 64;    -- keep small for fast sim; set to 640 for full frame
        IMG_HEIGHT : integer := 64;    -- set to 480 for full frame
        IN_FILE    : string  := "input_pixels.txt";
        OUT_FILE   : string  := "output_pixels.txt"
    );
end entity tb_sobel_top;

architecture sim of tb_sobel_top is

    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal in_valid  : std_logic := '0';
    signal in_pixel  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal out_valid : std_logic;
    signal out_pixel : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal done      : boolean := false;

    component sobel_top is
        generic (DATA_WIDTH : integer; IMG_WIDTH : integer; IMG_HEIGHT : integer);
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            in_valid  : in  std_logic;
            in_pixel  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            out_valid : out std_logic;
            out_pixel : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

begin

    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    dut : sobel_top
        generic map (DATA_WIDTH => DATA_WIDTH, IMG_WIDTH => IMG_WIDTH, IMG_HEIGHT => IMG_HEIGHT)
        port map (
            clk => clk, rst => rst,
            in_valid => in_valid, in_pixel => in_pixel,
            out_valid => out_valid, out_pixel => out_pixel
        );

    run : process
        file     fin    : text;
        file     fout   : text;
        variable fs_in  : file_open_status;
        variable fs_out : file_open_status;
        variable lin    : line;
        variable lout   : line;
        variable pv     : integer;
        variable icount : integer := 0;
        variable ocount : integer := 0;

        procedure capture is
        begin
            if out_valid = '1' then
                write(lout, to_integer(unsigned(out_pixel)));
                writeline(fout, lout);
                ocount := ocount + 1;
            end if;
        end procedure;
    begin
        file_open(fs_in, fin, IN_FILE, read_mode);
        assert fs_in = open_ok
            report "ERROR: could not open input file '" & IN_FILE & "'" severity failure;
        file_open(fs_out, fout, OUT_FILE, write_mode);
        assert fs_out = open_ok
            report "ERROR: could not open output file '" & OUT_FILE & "'" severity failure;

        rst <= '1'; in_valid <= '0';
        for i in 0 to 3 loop wait until rising_edge(clk); end loop;
        rst <= '0';

        while not endfile(fin) loop
            readline(fin, lin);
            read(lin, pv);
            in_pixel <= std_logic_vector(to_unsigned(pv, DATA_WIDTH));
            in_valid <= '1';
            wait until rising_edge(clk);
            capture;
            icount := icount + 1;
        end loop;

        in_valid <= '0';

        for i in 0 to (2*IMG_WIDTH + 32) loop
            wait until rising_edge(clk);
            capture;
        end loop;

        file_close(fin);
        file_close(fout);

        report "Streamed " & integer'image(icount) & " input pixels." severity note;
        report "Captured " & integer'image(ocount) & " output pixels." severity note;
        report "Expected interior pixels = " &
               integer'image((IMG_WIDTH-2)*(IMG_HEIGHT-2)) severity note;

        done <= true;
        wait;
    end process;

end architecture sim;
