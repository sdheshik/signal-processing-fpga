library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-------------------------------------------------------------------------------
-- Entity Declaration
-- Top‐level DSP system: modulator → IIR filter → FFT → FIFO → UART interface
-------------------------------------------------------------------------------
entity dsp_system_top is
    Port (
        clk           : in  std_logic;                 -- System clock
        start         : in  std_logic;                 -- Start acquisition trigger
        rst           : in  std_logic;                 -- Asynchronous reset (active high)
        uart_rx_i     : in  std_logic;                 -- UART receive line
        uart_tx_o     : out std_logic                  -- UART transmit line
    );
end entity dsp_system_top;

-------------------------------------------------------------------------------
-- Architecture: Behavioral
-------------------------------------------------------------------------------
architecture Behavioral of dsp_system_top is

    ---------------------------------------------------------------------------
    -- Internal Reset & Clock Signals
    ---------------------------------------------------------------------------
    signal rst_b               : std_logic := '0';     -- Synchronized reset for clk_b domain
    signal locked              : std_logic := '0';     -- PLL lock indicator
    signal clk_b               : std_logic := '0';     -- Buffered/derived clock

    -- Global reset: active when rst='1' or PLL not locked
    signal global_rst_n        : std_logic := '0';     
    signal rst_n               : std_logic := '1';     -- Active‐low system reset

    ---------------------------------------------------------------------------
    -- Configuration for FFT Core
    ---------------------------------------------------------------------------
    signal config_valid        : std_logic := '0';     -- Pulse to validly send FFT config
    signal cfg_sent            : std_logic := '0';     -- One‐time config sent flag

    ---------------------------------------------------------------------------
    -- Modulator → Filter → FFT Dataflow Signals
    ---------------------------------------------------------------------------
    signal modulated_signal    : std_logic_vector(15 downto 0) := (others => '0');
    signal filtered_signal     : std_logic_vector(15 downto 0) := (others => '0');

    -- FFT input / output (32‐bit complex samples)
    signal fft_input           : std_logic_vector(31 downto 0) := (others => '0');
    signal fft_output          : std_logic_vector(31 downto 0) := (others => '0');

    -- Handshaking
    signal filter_o_valid      : std_logic := '0';     -- Filter output valid
    signal filter_last         : std_logic := '0';     -- Filter end‐of‐frame
    signal fft_ready_s         : std_logic := '0';     -- FFT core ready to accept data
    signal fft_valid_s         : std_logic := '0';     -- FFT output valid
    signal fft_last            : std_logic := '0';     -- FFT end‐of‐frame

    -- Modulator handshakes
    signal filter_valid        : std_logic := '0';     -- Modulator output valid
    signal mod_last_s          : std_logic := '0';     -- Modulator end‐of‐frame

    ---------------------------------------------------------------------------
    -- AXI‐Stream FIFO for crossing clk/domains
    ---------------------------------------------------------------------------
    signal fifo_i_data         : std_logic_vector(31 downto 0) := (others => '0');
    signal fifo_data_out       : std_logic_vector(31 downto 0) := (others => '0');
    signal fifo_wr_en          : std_logic := '0';     -- Write enable (clk domain)
    signal fifo_rd_en          : std_logic := '0';     -- Read enable (clk_b domain)
    signal fifo_full           : std_logic := '0';     -- FIFO full flag
    signal fifo_empty          : std_logic := '0';     -- FIFO empty flag
    signal fill_afifo_sig      : std_logic := '0';     -- Pulse to request FIFO fill
    signal fill_afifo_sig_sync : std_logic := '0';     -- Synchronized pulse in clk domain

    ---------------------------------------------------------------------------
    -- UART Interface Signals
    ---------------------------------------------------------------------------
    signal uart_rx_data        : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_rx_valid       : std_logic := '0';     -- UART RX byte complete
    signal uart_tx_data        : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_tx_valid       : std_logic := '0';     -- UART TX data valid
    signal uart_tx_busy        : std_logic := '0';     -- UART TX busy flag
    signal tx_start            : std_logic := '0';     -- UART TX start pulse
    signal tx_done             : std_logic := '0';     -- UART TX done pulse

    ---------------------------------------------------------------------------
    -- Control Signals between sequencer blocks
    ---------------------------------------------------------------------------
    signal start_acquisition   : std_logic := '0';     -- Start modulation/filter chain
    signal request_fft         : std_logic := '0';     -- Request to read next FFT output

    ---------------------------------------------------------------------------
    -- Component Declarations
    ---------------------------------------------------------------------------
    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            reset    : in  std_logic;
            locked   : out std_logic;
            clk_out1 : out std_logic
        );
    end component;

    component SignalModulator is
        port (
            clk             : in  std_logic;
            rst_n           : in  std_logic;
            mod_valid       : in  std_logic;
            fft_ready       : in  std_logic;
            valid_input     : out std_logic;
            o_last_data     : out std_logic;
            modulated_signal: out std_logic_vector(15 downto 0)
        );
    end component;

    component filter_iir12 is
        port (
            clk         : in  std_logic;
            rst_n       : in  std_logic;
            i_valid     : in  std_logic;
            i_data      : in  std_logic_vector(15 downto 0);
            o_valid     : out std_logic;
            o_last_data : out std_logic;
            o_data      : out std_logic_vector(15 downto 0)
        );
    end component;

    component xfft_0 is
        port (
            aclk                : in  std_logic;
            aresetn             : in  std_logic;
            s_axis_config_tdata : in  std_logic_vector(15 downto 0);
            s_axis_config_tvalid: in  std_logic;
            s_axis_config_tready: out std_logic;
            s_axis_data_tdata   : in  std_logic_vector(31 downto 0);
            s_axis_data_tvalid  : in  std_logic;
            s_axis_data_tready  : out std_logic;
            s_axis_data_tlast   : in  std_logic;
            m_axis_data_tdata   : out std_logic_vector(31 downto 0);
            m_axis_data_tvalid  : out std_logic;
            m_axis_data_tready  : in  std_logic;
            m_axis_data_tlast   : out std_logic
        );
    end component;

    component fifo is
        generic (
            G_ADDR_WIDTH : positive := 9;
            G_DATA_WIDTH : positive := 32
        );
        port (
            i_write_clk  : in  std_logic;
            i_write_rstn : in  std_logic;
            i_write_en   : in  std_logic;
            i_write_data : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
            o_full       : out std_logic;

            i_read_clk   : in  std_logic;
            i_read_rstn  : in  std_logic;
            i_read_en    : in  std_logic;
            o_read_data  : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
            o_empty      : out std_logic
        );
    end component;

    component uart_rx is
        generic (
            G_BAUDRATE                : positive := 230400;
            G_OPERATING_FREQUENCY_MHZ : positive := 8
        );
        port (
            i_clk      : in  std_logic;
            i_rst_n    : in  std_logic;
            i_serial   : in  std_logic;
            o_data_byte: out std_logic_vector(7 downto 0);
            o_rx_done  : out std_logic
        );
    end component;

    component uart_tx is
        generic (
            G_BAUDRATE                : positive := 230400;
            G_OPERATING_FREQUENCY_MHZ : positive := 8
        );
        port (
            i_clk      : in  std_logic;
            i_rst_n    : in  std_logic;
            i_tx_start : in  std_logic;
            i_data_byte: in  std_logic_vector(7 downto 0);
            o_serial   : out std_logic;
            o_tx_busy  : out std_logic;
            o_tx_done  : out std_logic
        );
    end component;

    component sequencer is
        port (
            clk               : in  std_logic;
            rst_n             : in  std_logic;
            fft_data          : in  std_logic_vector(31 downto 0);
            fill_afifo        : in  std_logic;
            start             : in  std_logic;
            start_acquisition : out std_logic;
            request_fft       : out std_logic;
            fifo_wr_en        : out std_logic;
            fifo_i_data_reg   : out std_logic_vector(31 downto 0);
            fifo_full         : in  std_logic;
            fft_valid         : in  std_logic
        );
    end component;

    component sequ_2 is
        port (
            clk_b            : in  std_logic;
            rst_b            : in  std_logic;
            tx_active        : in  std_logic;
            uart_rx_data     : in  std_logic_vector(7 downto 0);
            uart_rx_valid    : in  std_logic;
            uart_tx_done     : in  std_logic;
            uart_tx_data     : out std_logic_vector(7 downto 0);
            uart_tx_start    : out std_logic;
            fill_afifo       : out std_logic;
            fifo_data_out    : in  std_logic_vector(31 downto 0);
            fifo_empty       : in  std_logic;
            fifo_rd_en       : out std_logic
        );
    end component;

    component pulse_synchronizer is
        port (
            i_clk_a   : in  std_logic;
            i_rst_n_a : in  std_logic;
            i_clk_b   : in  std_logic;
            i_rst_n_b : in  std_logic;
            i_pulse_a : in  std_logic;
            o_pulse_b : out std_logic
        );
    end component;

    component rst_sync is
        port (
            i_clk   : in  std_logic;
            i_rst_n : in  std_logic;
            o_rst_n : out std_logic
        );
    end component;

begin

    ----------------------------------------------------------------------------
    -- Global Reset & Clock Generation
    ----------------------------------------------------------------------------
    global_rst_n <= not rst and locked;    -- Active‐low global reset
    rst_n        <= global_rst_n;          -- Propagate to all domains

    -- Generate derived clock clk_b via PLL/DCM
    clk_inst : clk_wiz_0
        port map (
            clk_in1  => clk,
            reset    => rst,
            locked   => locked,
            clk_out1 => clk_b
        );

    ----------------------------------------------------------------------------
    -- One-Shot FFT Configuration Process
    ----------------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cfg_sent     <= '0';
            config_valid <= '0';
        elsif rising_edge(clk) then
            if cfg_sent = '0' then
                config_valid <= '1';
                cfg_sent     <= '1';
            else
                config_valid <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Dataflow: Modulator → IIR Filter → FFT Core
    ----------------------------------------------------------------------------

    U_SignalModulator : SignalModulator
        port map (
            clk             => clk,
            rst_n           => rst_n,
            mod_valid       => start_acquisition,
            fft_ready       => fft_ready_s,
            valid_input     => filter_valid,
            o_last_data     => mod_last_s,
            modulated_signal=> modulated_signal
        );

    U_IIRFilter : filter_iir12
        port map (
            clk         => clk,
            rst_n       => rst_n,
            i_valid     => filter_valid,
            i_data      => modulated_signal,
            o_valid     => filter_o_valid,
            o_last_data => filter_last,
            o_data      => filtered_signal
        );

    -- Sign-extend and pack filter output for FFT input
    fft_input <= std_logic_vector(resize(signed(filtered_signal), 32));

    U_XFFT : xfft_0
        port map (
            aclk                 => clk,
            aresetn              => rst_n,
            s_axis_config_tdata  => x"0029",        -- FFT length/config word
            s_axis_config_tvalid => config_valid,
            s_axis_config_tready => open,           -- (unconnected)     
            s_axis_data_tdata    => fft_input,
            s_axis_data_tvalid   => filter_o_valid,
            s_axis_data_tready   => fft_ready_s,
            s_axis_data_tlast    => filter_last,
            m_axis_data_tdata    => fft_output,
            m_axis_data_tvalid   => fft_valid_s,
            m_axis_data_tready   => request_fft,
            m_axis_data_tlast    => fft_last
        );

    ----------------------------------------------------------------------------
    -- Asynchronous FIFO for Clock‐Domain Crossing
    ----------------------------------------------------------------------------

    -- Synchronize fill request pulse into clk domain
    sync1 : pulse_synchronizer
        port map (
            i_clk_a   => clk_b,
            i_rst_n_a => rst_b,
            i_clk_b   => clk,
            i_rst_n_b => rst_n,
            i_pulse_a => fill_afifo_sig,
            o_pulse_b => fill_afifo_sig_sync
        );

    U_FIFO : fifo
        generic map (
            G_ADDR_WIDTH => 9,
            G_DATA_WIDTH => 32
        )
        port map (
            -- Write side (clk domain)
            i_write_clk  => clk,
            i_write_rstn => rst_n,
            i_write_en   => fifo_wr_en,
            i_write_data => fft_output,
            o_full       => fifo_full,

            -- Read side (clk_b domain)
            i_read_clk   => clk_b,
            i_read_rstn  => rst_b,
            i_read_en    => fifo_rd_en,
            o_read_data  => fifo_data_out,
            o_empty      => fifo_empty
        );

    ----------------------------------------------------------------------------
    -- Reset Synchronizer for clk_b Domain
    ----------------------------------------------------------------------------
    sync6 : rst_sync
        port map (
            i_clk   => clk_b,
            i_rst_n => rst_n,
            o_rst_n => rst_b
        );

    ----------------------------------------------------------------------------
    -- UART Rx/Tx Blocks (clk_b domain)
    ----------------------------------------------------------------------------
    uart_rx_inst : uart_rx
        generic map (
            G_BAUDRATE                => 230400,
            G_OPERATING_FREQUENCY_MHZ => 8
        )
        port map (
            i_clk       => clk_b,
            i_rst_n     => rst_b,
            i_serial    => uart_rx_i,
            o_data_byte => uart_rx_data,
            o_rx_done   => uart_rx_valid
        );

    uart_tx_inst : uart_tx
        generic map (
            G_BAUDRATE                => 230400,
            G_OPERATING_FREQUENCY_MHZ => 8
        )
        port map (
            i_clk       => clk_b,
            i_rst_n     => rst_b,
            i_tx_start  => tx_start,
            i_data_byte => uart_tx_data,
            o_serial    => uart_tx_o,
            o_tx_busy   => uart_tx_busy,
            o_tx_done   => tx_done
        );

    ----------------------------------------------------------------------------
    -- Sequencer: Controls data movement & UART interfacing
    ----------------------------------------------------------------------------
    U_Sequencer : sequencer
        port map (
            clk               => clk,
            rst_n             => rst_n,
            fft_data          => fft_output,
            fill_afifo        => fill_afifo_sig_sync,
            start             => start,
            fft_valid         => fft_valid_s,
            start_acquisition => start_acquisition,
            request_fft       => request_fft,
            fifo_wr_en        => fifo_wr_en,
            fifo_i_data_reg   => fifo_i_data,
            fifo_full         => fifo_full
        );

    P_Sequencer : sequ_2
        port map (
            clk_b           => clk_b,
            rst_b           => rst_b,
            tx_active       => uart_tx_busy,
            uart_rx_data    => uart_rx_data,
            uart_rx_valid   => uart_rx_valid,
            uart_tx_done    => tx_done,
            uart_tx_data    => uart_tx_data,
            uart_tx_start   => tx_start,
            fill_afifo      => fill_afifo_sig,
            fifo_data_out   => fifo_data_out,
            fifo_empty      => fifo_empty,
            fifo_rd_en      => fifo_rd_en
        );

end architecture Behavioral;
