library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library lib_filter;
use lib_filter.filter_pkg.all;

-------------------------------------------------------------------------------
-- Entity: filter_iir
-- Implements a configurable IIR filter (Alpha or Beta) using transposed
-- direct‐form II structure. Coefficients are provided by lib_filter.filter_pkg.
-------------------------------------------------------------------------------
entity filter_iir is
  generic (
    G_FILTER_TYPE : t_filter_iir_types := ALPHA  -- Select filter type
  );
  port (
    clk         : in  std_logic;                           -- System clock
    rst_n       : in  std_logic;                           -- Active‐low synchronous reset
    i_valid     : in  std_logic;                           -- Input sample valid
    i_data      : in  std_logic_vector(15 downto 0);       -- Input data word
    o_valid     : out std_logic;                           -- Output sample valid
    o_last_data : out std_logic;                           -- High on last valid sample
    o_data      : out std_logic_vector(15 downto 0)        -- Output filtered data
  );
end entity filter_iir;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of filter_iir is

  ---------------------------------------------------------------------------
  -- Internal Types & Signals
  ---------------------------------------------------------------------------
  -- Shift‐register arrays for past inputs (ve) and outputs (vs)
  type t_array_sig16 is array(2 downto 0) of signed(15 downto 0);

  signal ve       : t_array_sig16 := (others => (others => '0'));  -- Input pipeline
  signal vs       : t_array_sig16 := (others => (others => '0'));  -- Output pipeline

  -- Multiplier outputs (extended precision)
  signal mult_b0  : signed(23 downto 0);
  signal mult_b1  : signed(23 downto 0);
  signal mult_b2  : signed(23 downto 0);
  signal mult_a0  : signed(23 downto 0);
  signal mult_a1  : signed(23 downto 0);

  signal valid    : std_logic := '0';                            -- Delayed i_valid

begin

  ----------------------------------------------------------------------------
  -- Output Assignments
  ----------------------------------------------------------------------------
  -- Present filtered output (highest‐precision truncated to 16 bits)
  o_data      <= std_logic_vector(vs(0));
  o_valid     <= valid;
  -- Last‐data flag: asserted when input went low but we still have valid data
  o_last_data <= not i_valid and valid;

  ----------------------------------------------------------------------------
  -- Filter Difference Equation
  ----------------------------------------------------------------------------
  -- Compute new output sample vs(0) from pipeline multiplies
  vs(0) <= mult_b0(22 downto 7)
         + mult_b1(22 downto 7)
         + mult_b2(22 downto 7)
         - mult_a0(22 downto 7)
         - mult_a1(22 downto 7);

  ----------------------------------------------------------------------------
  -- Coefficient Multiply Blocks
  ----------------------------------------------------------------------------
  -- Alpha‐type filter coefficients
  g_alpha: if G_FILTER_TYPE = ALPHA generate
    mult_b0 <= ve(2) * COEFF_IIR_ALPHA_B0;
    mult_b1 <= ve(1) * COEFF_IIR_ALPHA_B1;
    mult_b2 <= ve(0) * COEFF_IIR_ALPHA_B2;
    mult_a0 <= vs(2) * COEFF_IIR_ALPHA_A0;
    mult_a1 <= vs(1) * COEFF_IIR_ALPHA_A1;
  end generate g_alpha;

  -- Beta‐type filter coefficients
  g_beta : if G_FILTER_TYPE = BETA generate
    mult_b0 <= ve(2) * COEFF_IIR_BETA_B0;
    mult_b1 <= ve(1) * COEFF_IIR_BETA_B1;
    mult_b2 <= ve(0) * COEFF_IIR_BETA_B2;
    mult_a0 <= vs(2) * COEFF_IIR_BETA_A0;
    mult_a1 <= vs(1) * COEFF_IIR_BETA_A1;
  end generate g_beta;

  ----------------------------------------------------------------------------
  -- Valid Signal Pipeline
  ----------------------------------------------------------------------------
  p_valid : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        valid <= '0';
      else
        valid <= i_valid;
      end if;
    end if;
  end process p_valid;

  ----------------------------------------------------------------------------
  -- Input Pipeline: Shift ve array on each valid sample
  ----------------------------------------------------------------------------
  g_shift_reg_ve : for i in 0 to 2 generate

    -- ve(0): load new input when valid
    g0 : if i = 0 generate
      p_reg0 : process(clk)
      begin
        if rising_edge(clk) then
          if rst_n = '0' then
            ve(0) <= (others => '0');
          elsif i_valid = '1' then
            ve(0) <= signed(i_data);
          else
            ve(0) <= (others => '0');
          end if;
        end if;
      end process p_reg0;
    end generate g0;

    -- ve(i>0): shift previous stage when valid
    g1 : if i > 0 generate
      p_regn : process(clk)
      begin
        if rising_edge(clk) then
          if rst_n = '0' then
            ve(i) <= (others => '0');
          elsif i_valid = '1' then
            ve(i) <= ve(i-1);
          else
            ve(i) <= (others => '0');
          end if;
        end if;
      end process p_regn;
    end generate g1;

  end generate g_shift_reg_ve;

  ----------------------------------------------------------------------------
  -- Output Pipeline: Shift vs array as samples are processed
  ----------------------------------------------------------------------------
  p_vs1 : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        vs(1) <= (others => '0');
      elsif i_valid = '1' then
        vs(1) <= vs(0);
      else
        vs(1) <= (others => '0');
      end if;
    end if;
  end process p_vs1;

  p_vs2 : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        vs(2) <= (others => '0');
      elsif i_valid = '1' then
        vs(2) <= vs(1);
      else
        vs(2) <= (others => '0');
      end if;
    end if;
  end process p_vs2;

end architecture rtl;
