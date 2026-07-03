--------------------------------------------------------------------------------
-- sobel_core.vhd
-- Computes the Sobel gradients and the approximate edge magnitude for one 3x3
-- window, using a 2-stage pipeline so the combinational depth stays shallow.
--
--   Gx = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20)
--   Gy = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02)
--   M  = |Gx| + |Gy|   (approximate magnitude), saturated to 8 bits.
--
-- Coefficients are only -2,-1,0,1,2, so *2 is a left shift and no general
-- multipliers are used. Intermediate signals are widened to avoid overflow:
-- each gradient fits in 11 bits signed (max magnitude 4*255 = 1020), and the
-- sum of two absolute values fits in 12 bits before saturation to 8 bits.
--
-- Stage 1: compute Gx, Gy (registered).
-- Stage 2: compute |Gx|+|Gy|, saturate (registered).
-- Valid is delayed by 2 cycles to match the pipeline latency.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sobel_core is
    generic (
        DATA_WIDTH : integer := 8
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        in_valid   : in  std_logic;
        p00, p01, p02 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        p10, p11, p12 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        p20, p21, p22 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        out_valid  : out std_logic;
        edge       : out std_logic_vector(DATA_WIDTH-1 downto 0)  -- saturated |Gx|+|Gy|
    );
end entity sobel_core;

architecture rtl of sobel_core is

    -- Widen unsigned 8-bit pixels to a 13-bit signed container. 13 bits holds the
    -- full gradient range (max |Gx| = 4*255 = 1020 < 2^12) with room for the sign,
    -- and every term below is 13 bits so no intermediate sum overflows.
    function sxt(v : std_logic_vector) return signed is
    begin
        return signed(resize(unsigned(v), 13));  -- 0..255 in a 13-bit signed container
    end function;

    signal gx_r, gy_r : signed(12 downto 0) := (others => '0'); -- stage-1 registered gradients
    signal v1         : std_logic := '0';
    signal v2         : std_logic := '0';
    signal edge_r     : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    process (clk)
        variable gx, gy       : signed(12 downto 0);
        variable agx, agy     : unsigned(12 downto 0);
        variable msum         : unsigned(13 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                gx_r <= (others=>'0'); gy_r <= (others=>'0');
                v1 <= '0'; v2 <= '0';
                edge_r <= (others=>'0');
            else
                -------------------------------------------------------------
                -- Stage 1: gradients. "* 2" done via shift-left-by-1 (sll).
                -------------------------------------------------------------
                gx := ( sxt(p02) + shift_left(sxt(p12),1) + sxt(p22) )
                    - ( sxt(p00) + shift_left(sxt(p10),1) + sxt(p20) );
                gy := ( sxt(p20) + shift_left(sxt(p21),1) + sxt(p22) )
                    - ( sxt(p00) + shift_left(sxt(p01),1) + sxt(p02) );
                gx_r <= gx;
                gy_r <= gy;
                v1   <= in_valid;

                -------------------------------------------------------------
                -- Stage 2: |Gx| + |Gy|, then saturate to 8 bits.
                -------------------------------------------------------------
                if gx_r(gx_r'high) = '1' then
                    agx := unsigned(-gx_r);
                else
                    agx := unsigned(gx_r);
                end if;
                if gy_r(gy_r'high) = '1' then
                    agy := unsigned(-gy_r);
                else
                    agy := unsigned(gy_r);
                end if;

                msum := resize(agx, 14) + resize(agy, 14);

                if msum > to_unsigned(255, 14) then
                    edge_r <= (others => '1');                 -- saturate to 255
                else
                    edge_r <= std_logic_vector(resize(msum, DATA_WIDTH));
                end if;
                v2 <= v1;
            end if;
        end if;
    end process;

    edge      <= edge_r;
    out_valid <= v2;

end architecture rtl;
