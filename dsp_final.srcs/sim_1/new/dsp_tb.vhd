library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dsp_system_top is
--  No ports in a testbench
end tb_dsp_system_top;

architecture Behavioral of tb_dsp_system_top is

    -- Component under test
    component dsp_system_top
        Port (
            clk        : in  std_logic;
            clk_b      : in  std_logic;
            start      : in std_logic;
            rst        : in  std_logic;
            led        : out std_logic_vector(15 downto 0);
            uart_rx_i  : in  std_logic;
            uart_tx_o  : out std_logic
        );
    end component;

    -- Testbench signals
    signal clk       : std_logic := '0';
    signal clk_b     : std_logic := '0';
    signal rst       : std_logic := '1';
    signal start_sig : std_logic := '0';
    signal uart_rx_i : std_logic := '1';
    signal led       : std_logic_vector(15 downto 0);
    signal uart_tx_o : std_logic;

    constant CLK_PERIOD    : time := 10 ns;    -- 100 MHz
    constant CLK_B_PERIOD  : time := 125 ns;   -- 8 MHz
    constant G_BAUDRATE: positive := 230400;
    constant G_OPERATING_FREQUENCY_MHZ: positive := 8;
    constant NB_CLKS_PER_BIT: integer := (G_OPERATING_FREQUENCY_MHZ * 1000000) / G_BAUDRATE;

begin

    -- Instantiate the DUT
    uut: dsp_system_top
        port map (
            clk       => clk,
            clk_b     => clk_b,
            start     => start_sig,
            rst       => rst,
            led       => led,
            uart_rx_i => uart_rx_i,
            uart_tx_o => uart_tx_o
        );

    -- Primary clock generation (100 MHz)
    clk_gen: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

        -- Secondary clock generation (8 MHz)
    clk_b_gen: process
    begin
        clk_b <= '0';
        wait for CLK_B_PERIOD/2;
        clk_b <= '1';
        wait for CLK_B_PERIOD/2;
    end process;



    -- Stimulus process
    stimulus: process
    -- Procedure to send one UART frame (start bit, 8 data bits, stop bit)
    procedure send_frame(byte: in std_logic_vector(7 downto 0)) is
      variable i: integer;
    begin
      -- Transmit Start Bit (logic 0)
      uart_rx_i <= '0';
      wait for CLK_B_PERIOD * NB_CLKS_PER_BIT;
      
      -- Transmit 8 data bits (LSB first)
      for i in 0 to 7 loop
        uart_rx_i <= byte(i);
        wait for CLK_B_PERIOD * NB_CLKS_PER_BIT;
      end loop;
      
      -- Transmit Stop Bit (logic 1)
      uart_rx_i <= '1';
      wait for CLK_B_PERIOD * NB_CLKS_PER_BIT;
    end procedure send_frame;




    begin
        -- Hold reset for 200 ns
        rst <= '1';
        wait for 200 ns;
        rst <= '0'; 
        wait for 100 ns;

        -- Pulse start to begin acquisition/modulation
        start_sig <= '1';
        wait for 23.5 us;

        -- Send first frame: 0x5A (binary 01011010)
        send_frame(x"5A");
    
        wait for 23.5 us;
        
        start_sig <= '0';

        wait for 50 ns;
    
        -- Send second frame: 0xA5 (binary 10100101)
        send_frame(x"A5");
    
        wait for 23.5 us;
    
        -- End simulation
        wait;
        end process;

end Behavioral;
