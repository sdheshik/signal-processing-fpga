library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity: sequencer
-- Generates control signals for starting data acquisition, requesting FFT
-- results, and writing FFT output into an asynchronous FIFO.
-------------------------------------------------------------------------------
entity sequencer is
  Port (
    clk               : in  std_logic;                    -- System clock
    rst_n             : in  std_logic;                    -- Active‐low synchronous reset
    fft_data          : in  std_logic_vector(31 downto 0);-- FFT output data
    fill_afifo        : in  std_logic;                    -- Pulse to begin FIFO fill
    start             : in  std_logic;                    -- External start trigger
    start_acquisition : out std_logic;                    -- Assert to start modulator
    request_fft       : out std_logic;                    -- Pulse to read next FFT word
    fifo_wr_en        : out std_logic;                    -- Enable write into FIFO
    fifo_i_data_reg   : out std_logic_vector(31 downto 0);-- Data to FIFO input register
    fifo_full         : in  std_logic;                    -- FIFO full flag
    fft_valid         : in  std_logic                     -- FFT output valid
  );
end entity sequencer;

-------------------------------------------------------------------------------
-- Architecture: Behavioral
-------------------------------------------------------------------------------
architecture Behavioral of sequencer is

  ---------------------------------------------------------------------------
  -- State Machine Definition
  ---------------------------------------------------------------------------
  type state_type is (IDLE, ACQUIRE, FILL_FIFO);
  signal p_state, n_state : state_type := IDLE;           -- Present and next state

  ---------------------------------------------------------------------------
  -- Internal Data Register
  ---------------------------------------------------------------------------
  signal fifo_data_reg    : std_logic_vector(31 downto 0) := (others => '0');

begin

  ----------------------------------------------------------------------------
  -- State Register Process
  -- Updates present state on rising edge or resets to IDLE on rst_n='0'.
  ----------------------------------------------------------------------------
  block_m : process(clk, rst_n)
  begin
    if rst_n = '0' then
      p_state <= IDLE;
    elsif rising_edge(clk) then
      p_state <= n_state;
    end if;
  end process block_m;

  ----------------------------------------------------------------------------
  -- Output Combinational Logic
  -- Drive control signals based on current state and input valid flags.
  ----------------------------------------------------------------------------
  block_g : process(p_state, fft_valid)
  begin
    -- Default assignments
    start_acquisition <= '0';
    request_fft       <= '0';
    fifo_wr_en        <= '0';
    fifo_i_data_reg   <= (others => '0');

    case p_state is
      ------------------------------------------------------------------------
      when IDLE =>
        -- Wait for external start
        null;

      ------------------------------------------------------------------------
      when ACQUIRE =>
        -- Assert acquisition until FIFO fill begins
        start_acquisition <= '1';

      ------------------------------------------------------------------------
      when FILL_FIFO =>
        -- Continue acquisition; request FFT and write when valid
        start_acquisition <= '1';
        request_fft       <= '1';
        fifo_i_data_reg   <= fft_data;
        if fft_valid = '1' then
          fifo_wr_en <= '1';
        end if;

      ------------------------------------------------------------------------
      when others =>
        -- Should not occur
        null;
    end case;
  end process block_g;

  ----------------------------------------------------------------------------
  -- Next‐State Combinational Logic
  -- Determine transitions based on FIFO full, fill request, and start.
  ----------------------------------------------------------------------------
  block_f : process(p_state, start, fill_afifo, fifo_full)
  begin
    case p_state is
      ------------------------------------------------------------------------
      when IDLE =>
        if start = '1' then
          n_state <= ACQUIRE;
        else
          n_state <= IDLE;
        end if;

      ------------------------------------------------------------------------
      when ACQUIRE =>
        if fill_afifo = '1' then
          n_state <= FILL_FIFO;
        else
          n_state <= ACQUIRE;
        end if;

      ------------------------------------------------------------------------
      when FILL_FIFO =>
        if fifo_full = '1' then
          n_state <= ACQUIRE;  -- Stop filling when full
        else
          n_state <= FILL_FIFO;
        end if;

      ------------------------------------------------------------------------
      when others =>
        n_state <= IDLE;
    end case;
  end process block_f;

end architecture Behavioral;
