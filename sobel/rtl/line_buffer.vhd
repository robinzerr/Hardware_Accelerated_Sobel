--------------------------------------------------------------------------------
-- line_buffer.vhd
-- Stores one full image row as a row-delay line. A pixel written at column c of
-- row r appears at the output when column c of row r+1 is being written -- i.e.
-- the output is the pixel from the PREVIOUS row at the same column.
--
-- IMPORTANT (cascading): the read is COMBINATIONAL (asynchronous) with respect
-- to the current column address, and the write is synchronous. This lets two
-- line buffers be cascaded (lb1.din = lb0.dout) to obtain pixels from one and
-- two rows back WITHOUT an extra pipeline register creeping into the row-2 path.
-- A registered read on a cascaded buffer would misalign the top window row.
--
-- The buffer is addressed by the caller's column counter (0..IMG_WIDTH-1).
-- This structure infers a simple dual-port distributed/block RAM in Vivado.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity line_buffer is
    generic (
        DATA_WIDTH : integer := 8;
        IMG_WIDTH  : integer := 640
    );
    port (
        clk  : in  std_logic;
        we   : in  std_logic;                                  -- write/advance enable
        addr : in  std_logic_vector(15 downto 0);              -- column index (0..IMG_WIDTH-1)
        din  : in  std_logic_vector(DATA_WIDTH-1 downto 0);    -- incoming pixel (current row)
        dout : out std_logic_vector(DATA_WIDTH-1 downto 0)     -- pixel from previous row, same column
    );
end entity line_buffer;

architecture rtl of line_buffer is
    type ram_t is array (0 to IMG_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
begin
    -- Synchronous write of the current-row pixel into this column's slot.
    process (clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                ram(to_integer(unsigned(addr))) <= din;
            end if;
        end if;
    end process;

    -- Combinational (read-before-write) output: the value currently stored at
    -- this column is the previous row's pixel, available in the SAME cycle the
    -- new pixel is presented. Cascading two of these therefore delays by exactly
    -- one and two rows with no extra register.
    dout <= ram(to_integer(unsigned(addr)));

end architecture rtl;
