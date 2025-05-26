library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library lib_cdc;
use lib_cdc.cdc_pkg.all;

-------------------------------------------------------------------------------
-- Entity: pulse_synchronizer
-- Safely transfers a single‐cycle pulse from clock domain A to clock domain B.
-- Uses a toggle‐flip technique plus a 2‐stage synchronizer to detect edges.
-------------------------------------------------------------------------------
entity pulse_synchronizer is
  port (
    i_clk_a   : in  std_logic;   -- Source clock domain
    i_rst_n_a : in  std_logic;   -- Active‐low reset in source domain
    i_clk_b   : in  std_logic;   -- Destination clock domain
    i_rst_n_b : in  std_logic;   -- Active‐low reset in destination domain
    i_pulse_a : in  std_logic;   -- Single‐cycle pulse in source domain
    o_pulse_b : out std_logic    -- Single‐cycle pulse in destination domain
  );
end entity pulse_synchronizer;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of pulse_synchronizer is

  ---------------------------------------------------------------------------
  -- Internal Signals
  ---------------------------------------------------------------------------
  signal toggle           : std_logic := '0';  -- Toggles on each source pulse
  signal toggle_sync      : std_logic := '0';  -- Synchronized toggle in dest domain
  signal toggle_sync_pipe : std_logic := '0';  -- Previous toggle_sync value
  signal pulse_out        : std_logic := '0';  -- Generated pulse in dest domain

begin

  ---------------------------------------------------------------------------
  -- Source‐Domain Toggle Process
  -- On each rising i_clk_a edge, if i_pulse_a asserted, invert the toggle.
  ---------------------------------------------------------------------------
  p_toggle : process(i_clk_a)
  begin
    if rising_edge(i_clk_a) then
      if i_rst_n_a = '0' then
        toggle <= '0';
      else
        if i_pulse_a = '1' then
          toggle <= not toggle;
        end if;
      end if;
    end if;
  end process p_toggle;

  ---------------------------------------------------------------------------
  -- 2‐Stage Synchronizer for toggle
  -- Uses generic synchronizer from lib_cdc to safely cross clock domains.
  ---------------------------------------------------------------------------
  u_toggle_sync : synchronizer
    port map (
      i_clk   => i_clk_b,
      i_rst_n => i_rst_n_b,
      i_data  => toggle,
      o_data  => toggle_sync
    );

  ---------------------------------------------------------------------------
  -- Output Pulse Generation
  -- Compare current and previous synchronized toggle to detect an edge.
  ---------------------------------------------------------------------------
  p_pulse_out : process(i_clk_b)
  begin
    if rising_edge(i_clk_b) then
      if i_rst_n_b = '0' then
        toggle_sync_pipe <= '0';
        pulse_out        <= '0';
      else
        -- Shift register stage
        toggle_sync_pipe <= toggle_sync;
        -- Generate pulse when toggle_sync toggles
        if toggle_sync /= toggle_sync_pipe then
          pulse_out <= '1';
        else
          pulse_out <= '0';
        end if;
      end if;
    end if;
  end process p_pulse_out;

  -- Output assignment
  o_pulse_b <= pulse_out;

end architecture rtl;
