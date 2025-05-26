----------------------------------------------------------------------------------
--
-- Project: ASPECT - Analyseur de SPECTre
-- Module Name: filter_pkg.vhd
-- Target Devices: Nexys A7 100T
-- Tool Versions: Vivado 2023.1
-- Description: Filter package
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package filter_pkg is

  type t_filter_types is (HIGH_PASS, LOW_PASS);

  constant COEFF_LOW_PASS_0 : signed(7 downto 0) := to_signed(9, 8);
  constant COEFF_LOW_PASS_1 : signed(7 downto 0) := to_signed(28, 8);
  constant COEFF_LOW_PASS_2 : signed(7 downto 0) := to_signed(28, 8);
  constant COEFF_LOW_PASS_3 : signed(7 downto 0) := to_signed(9, 8);

  constant COEFF_HIGH_PASS_0 : signed(7 downto 0) := to_signed(2, 8);
  constant COEFF_HIGH_PASS_1 : signed(7 downto 0) := to_signed(100, 8);
  constant COEFF_HIGH_PASS_2 : signed(7 downto 0) := to_signed(-100, 8);
  constant COEFF_HIGH_PASS_3 : signed(7 downto 0) := to_signed(2, 8);

  component filter is
    generic (
      G_FILTER_TYPE : t_filter_types;
      G_DATA_WIDTH  : positive);
    port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
      i_valid     : in  std_logic;
      i_data      : in  std_logic_vector(G_DATA_WIDTH-2 downto 0);
      o_valid     : out std_logic;
      o_last_data : out std_logic;
      o_data      : out std_logic_vector(G_DATA_WIDTH-1 downto 0));
  end component filter;


  ----------------------------------------
  --                 IIR                --
  ----------------------------------------

  type t_filter_iir_types is (ALPHA, BETA);

  -- ALPHA
  -- COEF 8bits signed fix point unit 1*int+7*frac
  constant COEFF_IIR_ALPHA_A2 : signed(7 downto 0)  := to_signed(127,8);
  constant COEFF_IIR_ALPHA_A1 : signed(7 downto 0)  := to_signed(21,8);
  constant COEFF_IIR_ALPHA_A0 : signed(7 downto 0)  := to_signed(107,8);
  constant COEFF_IIR_ALPHA_B2 : signed(7 downto 0)  := to_signed(14,8);
  constant COEFF_IIR_ALPHA_B1 : signed(7 downto 0)  := to_signed(0,8);
  constant COEFF_IIR_ALPHA_B0 : signed(7 downto 0)  := to_signed(-14,8);

  -- BETA
  -- COEF 8bits signed fix point unit 1*int+7*frac
  constant COEFF_IIR_BETA_A2 : signed(7 downto 0)  := to_signed(127,8);
  constant COEFF_IIR_BETA_A1 : signed(7 downto 0)  := to_signed(-21,8);
  constant COEFF_IIR_BETA_A0 : signed(7 downto 0)  := to_signed(107,8);
  constant COEFF_IIR_BETA_B2 : signed(7 downto 0)  := to_signed(15,8);
  constant COEFF_IIR_BETA_B1 : signed(7 downto 0)  := to_signed(0,8);
  constant COEFF_IIR_BETA_B0 : signed(7 downto 0)  := to_signed(-15,8);

  component filter_iir is
    generic (
      G_FILTER_TYPE : t_filter_iir_types);
    port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
      i_valid     : in  std_logic;
      i_data      : in  std_logic_vector(15 downto 0);
      o_valid     : out std_logic;
      o_last_data : out std_logic;
      o_data      : out std_logic_vector(15 downto 0));
  end component filter_iir;

end package filter_pkg;
