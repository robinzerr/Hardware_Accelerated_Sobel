--------------------------------------------------------------------------------
-- sobel_top.vhd
-- Top-level pipelined Sobel edge-detection accelerator.
--
-- Hierarchy:
--   sobel_top
--     |-- window_former        (contains 2x line_buffer + shift registers)
--     |     |-- line_buffer lb0
--     |     |-- line_buffer lb1
--     |-- sobel_core           (2-stage arithmetic pipeline)
--
-- Streaming interface:
--   in_valid / in_pixel : one 8-bit grayscale pixel per clock in raster order.
--   out_valid / out_pixel: filtered pixel, valid only for interior 3x3 windows.
--
-- Total latency from a pixel entering to its result: roughly 2*IMG_WIDTH + a few
-- cycles (line-buffer fill) plus the 2 pipeline stages of sobel_core.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sobel_top is
    generic (
        DATA_WIDTH : integer := 8;
        IMG_WIDTH  : integer := 640;
        IMG_HEIGHT : integer := 480
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;                                -- synchronous, active high
        in_valid  : in  std_logic;
        in_pixel  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        out_valid : out std_logic;
        out_pixel : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity sobel_top;

architecture rtl of sobel_top is

    signal w00, w01, w02 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal w10, w11, w12 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal w20, w21, w22 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal win_valid     : std_logic;

    component window_former is
        generic (DATA_WIDTH : integer; IMG_WIDTH : integer; IMG_HEIGHT : integer);
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            in_valid   : in  std_logic;
            in_pixel   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            p00, p01, p02 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            p10, p11, p12 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            p20, p21, p22 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            win_valid  : out std_logic
        );
    end component;

    component sobel_core is
        generic (DATA_WIDTH : integer);
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            in_valid   : in  std_logic;
            p00, p01, p02 : in std_logic_vector(DATA_WIDTH-1 downto 0);
            p10, p11, p12 : in std_logic_vector(DATA_WIDTH-1 downto 0);
            p20, p21, p22 : in std_logic_vector(DATA_WIDTH-1 downto 0);
            out_valid  : out std_logic;
            edge       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

begin

    u_window : window_former
        generic map (DATA_WIDTH => DATA_WIDTH, IMG_WIDTH => IMG_WIDTH, IMG_HEIGHT => IMG_HEIGHT)
        port map (
            clk => clk, rst => rst, in_valid => in_valid, in_pixel => in_pixel,
            p00 => w00, p01 => w01, p02 => w02,
            p10 => w10, p11 => w11, p12 => w12,
            p20 => w20, p21 => w21, p22 => w22,
            win_valid => win_valid
        );

    u_core : sobel_core
        generic map (DATA_WIDTH => DATA_WIDTH)
        port map (
            clk => clk, rst => rst, in_valid => win_valid,
            p00 => w00, p01 => w01, p02 => w02,
            p10 => w10, p11 => w11, p12 => w12,
            p20 => w20, p21 => w21, p22 => w22,
            out_valid => out_valid, edge => out_pixel
        );

end architecture rtl;
