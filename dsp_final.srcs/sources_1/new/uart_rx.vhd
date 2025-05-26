library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity: uart_rx
-- UART receiver (8N1). Detects start bit, samples 8 data bits LSB-first, checks
-- stop bit, and asserts o_rx_done for one cycle when a full byte is received.
-------------------------------------------------------------------------------
entity uart_rx is
  generic (
    G_BAUDRATE                : positive := 230400;       -- Baud rate (bits/sec)
    G_OPERATING_FREQUENCY_MHZ : positive := 8             -- Clock frequency (MHz)
  );
  port (
    i_clk       : in  std_logic;                         -- System clock
    i_rst_n     : in  std_logic;                         -- Active-low synchronous reset
    i_serial    : in  std_logic;                         -- Serial RX input
    o_data_byte : out std_logic_vector(7 downto 0);      -- Received byte (LSB first)
    o_rx_done   : out std_logic                          -- High for one clk when byte ready
  );
end entity uart_rx;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of uart_rx is

  ---------------------------------------------------------------------------
  -- Number of clock cycles per UART bit period
  ---------------------------------------------------------------------------
  constant NB_CLKS_PER_BIT : integer := (G_OPERATING_FREQUENCY_MHZ * 1_000_000) / G_BAUDRATE;

  ---------------------------------------------------------------------------
  -- State machine for RX process
  ---------------------------------------------------------------------------
  type state_t is (IDLE, START, DATA, STOP);

  ---------------------------------------------------------------------------
  -- Internal signals
  ---------------------------------------------------------------------------
  signal state       : state_t := IDLE;                      -- Current state
  signal clk_count   : integer range 0 to NB_CLKS_PER_BIT-1 := 0;  -- Bit-period counter
  signal bit_count   : integer range 0 to 7 := 0;            -- Data bit index
  signal shift_reg   : std_logic_vector(7 downto 0) := (others => '0'); -- Shift register
  signal rx_done_int : std_logic := '0';                     -- Internal rx_done pulse

begin

  ----------------------------------------------------------------------------
  -- Output assignments
  ----------------------------------------------------------------------------
  o_data_byte <= shift_reg;
  o_rx_done   <= rx_done_int;

  ----------------------------------------------------------------------------
  -- UART receive process
  -- Handles IDLE → START → DATA → STOP sequence, sampling at mid-bit and
  -- bit boundaries.
  ----------------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n = '0' then
        -- Reset all state and counters
        state       <= IDLE;
        clk_count   <= 0;
        bit_count   <= 0;
        shift_reg   <= (others => '0');
        rx_done_int <= '0';
      else
        -- Default: clear done pulse
        rx_done_int <= '0';

        case state is

          --------------------------------------------------
          -- IDLE: wait for start bit (line goes low)
          --------------------------------------------------
          when IDLE =>
            if i_serial = '0' then
              state     <= START;
              clk_count <= 0;
            end if;

          --------------------------------------------------
          -- START: sample halfway through start bit
          --------------------------------------------------
          when START =>
            if clk_count = (NB_CLKS_PER_BIT/2 - 1) then
              if i_serial = '0' then
                -- Valid start, proceed to DATA
                state     <= DATA;
                clk_count <= 0;
                bit_count <= 0;
              else
                -- False start, return to IDLE
                state <= IDLE;
              end if;
            else
              clk_count <= clk_count + 1;
            end if;

          --------------------------------------------------
          -- DATA: sample each data bit at bit boundary
          --------------------------------------------------
          when DATA =>
            if clk_count = NB_CLKS_PER_BIT-1 then
              clk_count                    <= 0;
              shift_reg(bit_count)         <= i_serial;
              if bit_count = 7 then
                state    <= STOP;
              else
                bit_count <= bit_count + 1;
              end if;
            else
              clk_count <= clk_count + 1;
            end if;

          --------------------------------------------------
          -- STOP: sample stop bit, then signal done
          --------------------------------------------------
          when STOP =>
            if clk_count = NB_CLKS_PER_BIT-1 then
              state       <= IDLE;
              rx_done_int <= '1';  -- one-cycle pulse
            else
              clk_count <= clk_count + 1;
            end if;

          when others =>
            state <= IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
