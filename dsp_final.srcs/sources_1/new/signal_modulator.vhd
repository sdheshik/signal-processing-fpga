library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity: SignalModulator
-- Generates a signed 16‐bit “modulated” output by multiplying a sine and
-- square lookup from ROMs under control of a simple handshake/state machine.
-------------------------------------------------------------------------------
entity SignalModulator is
  Port (
    clk              : in  std_logic;                     -- System clock
    rst_n            : in  std_logic;                     -- Active‐low synchronous reset
    mod_valid        : in  std_logic;                     -- Start modulation cycle
    fft_ready        : in  std_logic;                     -- FFT core ready for next sample
    valid_input      : out std_logic;                     -- Pulse when new sample available
    o_last_data      : out std_logic;                     -- High when this is the last sample
    modulated_signal : out std_logic_vector(15 downto 0)  -- Clipped 16‐bit modulated output
  );
end entity SignalModulator;

-------------------------------------------------------------------------------
-- Architecture: Behavioral
-------------------------------------------------------------------------------
architecture Behavioral of SignalModulator is

  ---------------------------------------------------------------------------
  -- Internal Signals
  ---------------------------------------------------------------------------
  signal rom_sin_data       : signed(15 downto 0) := (others => '0');  -- Sine ROM output
  signal rom_square_data    : signed(15 downto 0) := (others => '0');  -- Square ROM output
  signal add_addr           : std_logic := '0';                        -- Enable address increment
  signal addr               : std_logic_vector(8 downto 0) := (others => '0'); -- Current ROM address
  signal modulated_signal_sig : signed(31 downto 0) := (others => '0');-- Full‐width product

  ---------------------------------------------------------------------------
  -- State Machine Definition
  ---------------------------------------------------------------------------
  type state_type is (IDLE, SEND_DATA, PAUSE, INTER);  -- Control states
  signal p_state, n_state : state_type;               -- Present and Next state

  ---------------------------------------------------------------------------
  -- Component Declarations
  ---------------------------------------------------------------------------
  component rom_sin is
    generic (
      G_ROM_FILE   : string   := "sin.rom";
      G_ADDR_WIDTH : positive := 9;
      G_DATA_WIDTH : positive := 16
    );
    port (
      clk    : in  std_logic;
      rst_n  : in  std_logic;
      i_addr : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
      o_data : out signed(G_DATA_WIDTH-1 downto 0)
    );
  end component;

  component rom_square is
    generic (
      G_ROM_FILE   : string   := "square.rom";
      G_ADDR_WIDTH : positive := 9;
      G_DATA_WIDTH : positive := 16
    );
    port (
      clk    : in  std_logic;
      rst_n  : in  std_logic;
      i_addr : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
      o_data : out signed(G_DATA_WIDTH-1 downto 0)
    );
  end component;

begin

  ---------------------------------------------------------------------------
  -- ROM Instantiations
  ---------------------------------------------------------------------------
  U_RomSin : rom_sin
    port map (
      clk    => clk,
      rst_n  => rst_n,
      i_addr => addr,
      o_data => rom_sin_data
    );

  U_RomSquare : rom_square
    port map (
      clk    => clk,
      rst_n  => rst_n,
      i_addr => addr,
      o_data => rom_square_data
    );

  ---------------------------------------------------------------------------
  -- Multiply & Address Increment
  -- When add_addr='1', compute product and bump address; assert valid_input.
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if add_addr = '1' then
        modulated_signal_sig <= rom_sin_data * rom_square_data;
        addr                 <= std_logic_vector(unsigned(addr) + 1);
        valid_input          <= '1';
      else
        valid_input          <= '0';
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- State Register: Update present state on rising clock or reset to IDLE
  ---------------------------------------------------------------------------
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      p_state <= IDLE;
    elsif rising_edge(clk) then
      p_state <= n_state;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Next‐State Logic: Determine add_addr enable per state
  ---------------------------------------------------------------------------
  process(p_state)
  begin
    case p_state is
      when IDLE     => add_addr <= '0';
      when PAUSE    => add_addr <= '0';
      when INTER    => add_addr <= '0';
      when SEND_DATA=> add_addr <= '1';
      when others   => add_addr <= '0';
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- Next‐State Logic: Transition between IDLE, SEND_DATA, PAUSE, INTER
  ---------------------------------------------------------------------------
  process(fft_ready, mod_valid, addr, p_state)
  begin
    case p_state is
      when IDLE =>
        if mod_valid = '1' then
          n_state <= SEND_DATA;
        else
          n_state <= IDLE;
        end if;

      when SEND_DATA =>
        -- Always stay here once started
        n_state <= SEND_DATA;

      when PAUSE =>
        if fft_ready = '1' then
          n_state <= INTER;
        else
          n_state <= PAUSE;
        end if;

      when INTER =>
        -- After an inter-sample gap, send next
        n_state <= SEND_DATA;

      when others =>
        n_state <= IDLE;
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- Output Clipping: Limit 32‐bit product to signed 16‐bit range
  ---------------------------------------------------------------------------
  process(modulated_signal_sig)
  begin
    if modulated_signal_sig > to_signed(32767, 32) then
      modulated_signal <= std_logic_vector(to_signed(32767, 16));
    elsif modulated_signal_sig < to_signed(-32768, 32) then
      modulated_signal <= std_logic_vector(to_signed(-32768, 16));
    else
      modulated_signal <= std_logic_vector(modulated_signal_sig(15 downto 0));
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Last‐Data Flag: Assert when address wraps to maximum
  ---------------------------------------------------------------------------
  o_last_data <= '1' when addr = "111111111" else '0';

end architecture Behavioral;
