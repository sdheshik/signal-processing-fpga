library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity: uart_tx
-- UART transmitter (8N1). Sends start bit, 8 data bits LSB-first, stop bit,
-- and provides busy/done handshaking signals.
-------------------------------------------------------------------------------
entity uart_tx is
  generic (
    G_BAUDRATE                : positive := 230400;  -- Baud rate (bits/sec)
    G_OPERATING_FREQUENCY_MHZ : positive := 8        -- Clock frequency (MHz)
  );
  port (
    i_clk       : in  std_logic;                         -- System clock
    i_rst_n     : in  std_logic;                         -- Active-low sync reset
    i_tx_start  : in  std_logic;                         -- Pulse to start transmission
    i_data_byte : in  std_logic_vector(7 downto 0);      -- Byte to transmit (LSB first)
    o_serial    : out std_logic;                         -- Serial TX output
    o_tx_busy   : out std_logic;                         -- High while transmitting
    o_tx_done   : out std_logic                          -- One-cycle pulse when done
  );
end entity uart_tx;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of uart_tx is

  ---------------------------------------------------------------------------
  -- Bit‐period clock count
  ---------------------------------------------------------------------------
  constant NB_CLKS_PER_BIT : integer := (G_OPERATING_FREQUENCY_MHZ * 1_000_000) / G_BAUDRATE;

  ---------------------------------------------------------------------------
  -- State machine states
  ---------------------------------------------------------------------------
  type state_t is (IDLE, START, DATA, STOP);

  ---------------------------------------------------------------------------
  -- Internal signals
  ---------------------------------------------------------------------------
  signal state       : state_t := IDLE;                       -- Current state
  signal clk_count   : integer range 0 to NB_CLKS_PER_BIT-1 := 0; -- Bit‐period counter
  signal bit_count   : integer range 0 to 7 := 0;             -- Data bit index
  signal shift_reg   : std_logic_vector(7 downto 0) := (others => '0'); -- Shift register
  signal serial_out  : std_logic := '1';                      -- TX line output
  signal busy_int    : std_logic := '0';                      -- Internal busy flag
  signal done_int    : std_logic := '0';                      -- Internal done pulse

begin

  ----------------------------------------------------------------------------
  -- Output assignments
  ----------------------------------------------------------------------------
  o_serial  <= serial_out;
  o_tx_busy <= busy_int;
  o_tx_done <= done_int;

  ----------------------------------------------------------------------------
  -- UART transmit process
  -- Handles IDLE → START → DATA → STOP sequence, outputting bits at each
  -- bit‐period boundary.
  ----------------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n = '0' then
        -- Reset all internal state
        state      <= IDLE;
        clk_count  <= 0;
        bit_count  <= 0;
        shift_reg  <= (others => '0');
        serial_out <= '1';    -- Idle line is high
        busy_int   <= '0';
        done_int   <= '0';
      else
        -- Clear done pulse by default
        done_int <= '0';

        case state is
          --------------------------------------------------
          -- IDLE: wait for transmit start
          --------------------------------------------------
          when IDLE =>
            serial_out <= '1';  -- Idle line high
            busy_int   <= '0';
            if i_tx_start = '1' then
              shift_reg <= i_data_byte;
              state     <= START;
              clk_count <= 0;
              busy_int  <= '1';
            end if;

          --------------------------------------------------
          -- START: drive start bit low
          --------------------------------------------------
          when START =>
            serial_out <= '0';
            if clk_count = NB_CLKS_PER_BIT-1 then
              clk_count <= 0;
              state     <= DATA;
              bit_count <= 0;
            else
              clk_count <= clk_count + 1;
            end if;

          --------------------------------------------------
          -- DATA: shift out data bits LSB-first
          --------------------------------------------------
          when DATA =>
            serial_out <= shift_reg(bit_count);
            if clk_count = NB_CLKS_PER_BIT-1 then
              clk_count <= 0;
              if bit_count = 7 then
                state <= STOP;
              else
                bit_count <= bit_count + 1;
              end if;
            else
              clk_count <= clk_count + 1;
            end if;

          --------------------------------------------------
          -- STOP: drive stop bit high and signal done
          --------------------------------------------------
          when STOP =>
            serial_out <= '1';
            if clk_count = NB_CLKS_PER_BIT-1 then
              state    <= IDLE;
              done_int <= '1';    -- One-cycle done pulse
            else
              clk_count <= clk_count + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
