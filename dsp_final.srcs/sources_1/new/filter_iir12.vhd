library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library lib_filter;
use lib_filter.filter_pkg.all;

-------------------------------------------------------------------------------
-- Entity: filter_iir12
-- Cascades six 2nd-order IIR stages (Alpha/Beta alternating) to form a
-- 12th-order filter. Each stage is an instance of filter_iir from lib_filter.
-------------------------------------------------------------------------------
entity filter_iir12 is
  port (
    clk         : in  std_logic;                    -- System clock
    rst_n       : in  std_logic;                    -- Active-low synchronous reset
    i_valid     : in  std_logic;                    -- Input sample valid pulse
    i_data      : in  std_logic_vector(15 downto 0);-- 16-bit input sample
    o_valid     : out std_logic;                    -- Output sample valid pulse
    o_last_data : out std_logic;                    -- High on last valid output
    o_data      : out std_logic_vector(15 downto 0) -- 16-bit filtered output
  );
end entity filter_iir12;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of filter_iir12 is

  ---------------------------------------------------------------------------
  -- Internal Types & Signals
  ---------------------------------------------------------------------------
  -- Pipeline storage for intermediate filter outputs
  type t_array_sig16 is array(4 downto 0) of std_logic_vector(15 downto 0);
  signal data  : t_array_sig16 := (others => (others => '0')); -- Data through each stage

  -- Valid flags between stages
  signal valid : std_logic_vector(4 downto 0) := (others => '0');

begin

  ----------------------------------------------------------------------------
  -- Stage 1: 2nd-order IIR (Alpha)
  ----------------------------------------------------------------------------
  u_filter_iir2 : filter_iir
    generic map (
      G_FILTER_TYPE => ALPHA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => i_valid,
      i_data      => i_data,
      o_valid     => valid(0),
      o_last_data => open,      -- internal only
      o_data      => data(0)
    );

  ----------------------------------------------------------------------------
  -- Stage 2: 2nd-order IIR (Beta)
  ----------------------------------------------------------------------------
  u_filter_iir4 : filter_iir
    generic map (
      G_FILTER_TYPE => BETA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => valid(0),
      i_data      => data(0),
      o_valid     => valid(1),
      o_last_data => open,
      o_data      => data(1)
    );

  ----------------------------------------------------------------------------
  -- Stage 3: 2nd-order IIR (Alpha)
  ----------------------------------------------------------------------------
  u_filter_iir6 : filter_iir
    generic map (
      G_FILTER_TYPE => ALPHA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => valid(1),
      i_data      => data(1),
      o_valid     => valid(2),
      o_last_data => open,
      o_data      => data(2)
    );

  ----------------------------------------------------------------------------
  -- Stage 4: 2nd-order IIR (Beta)
  ----------------------------------------------------------------------------
  u_filter_iir8 : filter_iir
    generic map (
      G_FILTER_TYPE => BETA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => valid(2),
      i_data      => data(2),
      o_valid     => valid(3),
      o_last_data => open,
      o_data      => data(3)
    );

  ----------------------------------------------------------------------------
  -- Stage 5: 2nd-order IIR (Alpha)
  ----------------------------------------------------------------------------
  u_filter_iir10 : filter_iir
    generic map (
      G_FILTER_TYPE => ALPHA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => valid(3),
      i_data      => data(3),
      o_valid     => valid(4),
      o_last_data => open,
      o_data      => data(4)
    );

  ----------------------------------------------------------------------------
  -- Stage 6: 2nd-order IIR (Beta) → Final Output
  ----------------------------------------------------------------------------
  u_filter_iir12 : filter_iir
    generic map (
      G_FILTER_TYPE => BETA
    )
    port map (
      clk         => clk,
      rst_n       => rst_n,
      i_valid     => valid(4),
      i_data      => data(4),
      o_valid     => o_valid,
      o_last_data => o_last_data,
      o_data      => o_data
    );

end architecture rtl;
