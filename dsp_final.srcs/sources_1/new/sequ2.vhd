library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity: sequ_2
-- Command sequencer: listens for UART command 0x5A to fill FIFO, 0xA5 to read,
-- then streams 32-bit words from FIFO byte-wise over UART.
-------------------------------------------------------------------------------
entity sequ_2 is
  port (
    clk_b         : in  std_logic;                     -- Control/UART clock
    rst_b         : in  std_logic;                     -- Active-low reset
    tx_active     : in  std_logic;                     -- UART TX busy flag
    uart_rx_data  : in  std_logic_vector(7 downto 0);  -- Received UART byte
    uart_rx_valid : in  std_logic;                     -- High one cycle when RX byte ready
    uart_tx_done  : in  std_logic;                     -- High one cycle when TX finishes
    uart_tx_data  : out std_logic_vector(7 downto 0);  -- Byte to transmit
    uart_tx_start : out std_logic;                     -- Pulse to start TX
    fifo_rd_en    : out std_logic;                     -- FIFO read enable
    fill_afifo    : out std_logic;                     -- Pulse to begin FIFO fill
    fifo_data_out : in  std_logic_vector(31 downto 0); -- Word read from FIFO
    fifo_empty    : in  std_logic                       -- High when FIFO empty
  );
end entity sequ_2;

-------------------------------------------------------------------------------
-- Architecture: Behavioral
-------------------------------------------------------------------------------
architecture Behavioral of sequ_2 is

  -----------------------------------------------------------------------------
  -- State Machine Definition
  -----------------------------------------------------------------------------
  type t_state is (S_IDLE1, S_FILL, S_IDLE2, S_READ, S_SEND, S_WAIT);
  signal state     : t_state := S_IDLE1;          -- Current state

  -----------------------------------------------------------------------------
  -- UART Command Latching
  -----------------------------------------------------------------------------
  signal prev_rx_v : std_logic := '0';            -- Previous uart_rx_valid
  signal cmd_valid : std_logic := '0';            -- High one cycle on new RX byte
  signal cmd_byte  : std_logic_vector(7 downto 0) := (others => '0'); -- Latched byte

  -----------------------------------------------------------------------------
  -- FIFO Data & Byte Index
  -----------------------------------------------------------------------------
  signal fifo_word : std_logic_vector(31 downto 0) := (others => '0'); -- Current FIFO word
  signal byte_idx  : integer range 0 to 3 := 0;    -- Byte index (0 = LSB)

  -----------------------------------------------------------------------------
  -- Registered Outputs
  -----------------------------------------------------------------------------
  signal rd_en_r    : std_logic := '0';           -- Registered FIFO read enable
  signal fill_r     : std_logic := '0';           -- Registered fill pulse
  signal tx_data_r  : std_logic_vector(7 downto 0) := (others => '0');-- Registered TX data
  signal tx_start_r : std_logic := '0';           -- Registered TX start pulse

begin

  -----------------------------------------------------------------------------
  -- Process: Detect Rising Edge of uart_rx_valid
  -- Latch incoming command byte on its arrival.
  -----------------------------------------------------------------------------
  process(clk_b, rst_b)
  begin
    if rst_b = '0' then
      prev_rx_v <= '0';
      cmd_valid <= '0';
      cmd_byte  <= (others => '0');
    elsif rising_edge(clk_b) then
      prev_rx_v <= uart_rx_valid;
      if uart_rx_valid = '1' and prev_rx_v = '0' then
        cmd_valid <= '1';
        cmd_byte  <= uart_rx_data;
      else
        cmd_valid <= '0';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Main FSM: Handle FIFO Fill and Read Commands
  -- Streams FIFO words over UART one byte at a time.
  -----------------------------------------------------------------------------
  process(clk_b, rst_b)
  begin
    if rst_b = '0' then
      state      <= S_IDLE1;
      rd_en_r    <= '0';
      fill_r     <= '0';
      tx_data_r  <= (others => '0');
      tx_start_r <= '0';
      byte_idx   <= 0;
      fifo_word  <= (others => '0');
    elsif rising_edge(clk_b) then
      -- Default outputs de-asserted each cycle
      rd_en_r    <= '0';
      fill_r     <= '0';
      tx_start_r <= '0';

      case state is

        when S_IDLE1 =>
          -- Wait for fill command (0x5A)
          if cmd_valid = '1' and cmd_byte = x"5A" then
            fill_r <= '1';
            state  <= S_FILL;
          end if;

        when S_FILL =>
          -- After issuing fill pulse, go to idle2 for read
          state <= S_IDLE2;

        when S_IDLE2 =>
          -- Wait for read command (0xA5)
          if cmd_valid = '1' and cmd_byte = x"A5" then
            state <= S_READ;
          end if;

        when S_READ =>
          -- If FIFO has data, read word and proceed to send
          if fifo_empty = '0' then
            rd_en_r   <= '1';
            fifo_word <= fifo_data_out;
            byte_idx  <= 0;
            state     <= S_SEND;
          else
            -- No data: back to initial idle
            state <= S_IDLE1;
          end if;

        when S_SEND =>
          -- Send a byte when UART is not busy
          if tx_active = '0' then
            tx_data_r  <= fifo_word((byte_idx*8+7) downto (byte_idx*8));
            tx_start_r <= '1';
            state      <= S_WAIT;
          end if;

        when S_WAIT =>
          -- After TX done, send next byte or read next word
          if uart_tx_done = '1' then
            if byte_idx < 3 then
              byte_idx <= byte_idx + 1;
              state    <= S_SEND;
            else
              state    <= S_READ;
            end if;
          end if;

        when others =>
          -- Default safe state
          state <= S_IDLE1;
      end case;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Output Assignments to Top‐Level Ports
  -----------------------------------------------------------------------------
  fifo_rd_en    <= rd_en_r;
  fill_afifo    <= fill_r;
  uart_tx_data  <= tx_data_r;
  uart_tx_start <= tx_start_r;

end architecture Behavioral;
