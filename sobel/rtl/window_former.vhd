--------------------------------------------------------------------------------
-- window_former.vhd
-- Assembles a 3x3 pixel window from a raster pixel stream, using two cascaded
-- COMBINATIONAL-read line buffers plus per-row shift registers.
--
-- Vertical taps (same column, three rows):
--   row0_pix = in_pixel                      (current row r0)
--   row1_pix = lb0.dout (comb. read)         (row r-1)
--   row2_pix = lb1.dout (comb. read)         (row r-2)
-- Because the line-buffer reads are combinational, all three are aligned to the
-- SAME column in the SAME cycle -- no compensation register is needed.
--
-- Horizontal taps: three shift registers (one per row) hold columns
--   (_0,_1,_2) = (c-2, c-1, c) with the newest column at tap _2.
--
-- Window layout (p22 newest, bottom-right):
--        col-2   col-1   col
--   r-2   p00     p01     p02
--   r-1   p10     p11     p12
--   r0    p20     p21     p22
-- Centre p11 corresponds to image pixel (row_cnt-1, col_cnt-1).
--
-- win_valid marks interior pixels only (centre row in [1,H-2], col in [1,W-2]).
-- Border pixels are flagged invalid rather than zero-padded.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity window_former is
    generic (
        DATA_WIDTH : integer := 8;
        IMG_WIDTH  : integer := 640;
        IMG_HEIGHT : integer := 480
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;                                 -- synchronous, active high
        in_valid   : in  std_logic;                                 -- new pixel present on in_pixel
        in_pixel   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        p00, p01, p02 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        p10, p11, p12 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        p20, p21, p22 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_valid  : out std_logic
    );
end entity window_former;

architecture rtl of window_former is

    signal col_cnt  : unsigned(15 downto 0) := (others => '0');
    signal row_cnt  : unsigned(15 downto 0) := (others => '0');
    signal addr     : std_logic_vector(15 downto 0);

    signal row0_pix : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal row1_pix : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal row2_pix : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal sr0_0, sr0_1, sr0_2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sr1_0, sr1_1, sr1_2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sr2_0, sr2_1, sr2_2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal win_valid_i : std_logic := '0';

    component line_buffer is
        generic (DATA_WIDTH : integer; IMG_WIDTH : integer);
        port (
            clk  : in  std_logic;
            we   : in  std_logic;
            addr : in  std_logic_vector(15 downto 0);
            din  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            dout : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

begin

    -- Address the line buffers with the CURRENT arriving pixel's column so the
    -- combinational reads return the same column from the previous rows.
    addr     <= std_logic_vector(col_cnt);
    row0_pix <= in_pixel;

    lb0 : line_buffer
        generic map (DATA_WIDTH => DATA_WIDTH, IMG_WIDTH => IMG_WIDTH)
        port map (clk => clk, we => in_valid, addr => addr, din => row0_pix, dout => row1_pix);

    lb1 : line_buffer
        generic map (DATA_WIDTH => DATA_WIDTH, IMG_WIDTH => IMG_WIDTH)
        port map (clk => clk, we => in_valid, addr => addr, din => row1_pix, dout => row2_pix);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                col_cnt     <= (others => '0');
                row_cnt     <= (others => '0');
                win_valid_i <= '0';
                sr0_0 <= (others=>'0'); sr0_1 <= (others=>'0'); sr0_2 <= (others=>'0');
                sr1_0 <= (others=>'0'); sr1_1 <= (others=>'0'); sr1_2 <= (others=>'0');
                sr2_0 <= (others=>'0'); sr2_1 <= (others=>'0'); sr2_2 <= (others=>'0');
            elsif in_valid = '1' then
                -- Shift each row one tap left; newest column enters at tap _2.
                sr0_0 <= sr0_1; sr0_1 <= sr0_2; sr0_2 <= row2_pix;  -- top row (r-2)
                sr1_0 <= sr1_1; sr1_1 <= sr1_2; sr1_2 <= row1_pix;  -- middle row (r-1)
                sr2_0 <= sr2_1; sr2_1 <= sr2_2; sr2_2 <= row0_pix;  -- bottom row (r0)

                -- Advance column/row position of the pixel that just arrived.
                if col_cnt = to_unsigned(IMG_WIDTH-1, 16) then
                    col_cnt <= (others => '0');
                    if row_cnt /= to_unsigned(IMG_HEIGHT-1, 16) then
                        row_cnt <= row_cnt + 1;
                    end if;
                else
                    col_cnt <= col_cnt + 1;
                end if;

                -- After this shift the taps hold image columns (col-2,col-1,col)
                -- and the rows hold (row-2,row-1,row). The window centre is image
                -- pixel (row_cnt-1, col_cnt-1); it is interior when row_cnt in
                -- [2,H-1] and col_cnt in [2,W-1].
                if (row_cnt >= 2) and (col_cnt >= 2) then
                    win_valid_i <= '1';
                else
                    win_valid_i <= '0';
                end if;
            else
                win_valid_i <= '0';
            end if;
        end if;
    end process;

    p00 <= sr0_0; p01 <= sr0_1; p02 <= sr0_2;
    p10 <= sr1_0; p11 <= sr1_1; p12 <= sr1_2;
    p20 <= sr2_0; p21 <= sr2_1; p22 <= sr2_2;

    win_valid <= win_valid_i;

end architecture rtl;
