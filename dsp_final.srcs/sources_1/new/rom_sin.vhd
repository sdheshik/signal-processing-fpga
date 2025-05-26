library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.TEXTIO.ALL;

-------------------------------------------------------------------------------
-- Entity: rom_sin
-- ROM‐based sine lookup table. At elaboration, reads a text file of 16-bit
-- words into a constant ROM array indexed by a G_ADDR_WIDTH-bit address.
-------------------------------------------------------------------------------
entity rom_sin is
  generic (
    G_ROM_FILE   : string   := "sin.rom";       -- Path/name of the ROM initialization file
    G_ADDR_WIDTH : positive := 9;               -- Address bus width (depth = 2**G_ADDR_WIDTH)
    G_DATA_WIDTH : positive := 16               -- Data word width
  );
  port (
    clk    : in  std_logic;                                    -- System clock
    rst_n  : in  std_logic;                                    -- Active-low synchronous reset
    i_addr : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);    -- Read address
    o_data : out signed(G_DATA_WIDTH-1 downto 0)                -- Output data word (signed)
  );
end entity rom_sin;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of rom_sin is

  ---------------------------------------------------------------------------
  -- Type Declaration: ROM array
  --  An array of 2**G_ADDR_WIDTH entries, each G_DATA_WIDTH bits wide
  ---------------------------------------------------------------------------
  type t_rom_array is array (0 to 2**G_ADDR_WIDTH-1) of
                       std_logic_vector(G_DATA_WIDTH-1 downto 0);

  ---------------------------------------------------------------------------
  -- Function: load_rom
  -- Impure function reads a text file at elaboration time into a ROM array.
  ---------------------------------------------------------------------------
  impure function load_rom(
      constant file_name : in string
    ) return t_rom_array is

    -- File handle for reading text file
    file                     romfile         : text;
    -- Working ROM array
    variable rom             : t_rom_array;
    -- File open status
    variable open_status     : file_open_status := NAME_ERROR;
    -- TextIO line buffer
    variable L               : line;
    -- Line counter
    variable Lnum            : natural := 0;
    -- Success flag for hread
    variable read_ok         : boolean := true;
    -- Next write address in ROM
    variable next_address    : integer := 0;
    -- Raw data read from each line (always 16 bits wide)
    variable data            : std_logic_vector(15 downto 0);
    -- Prefix for assertion messages
    constant report_header   : string := "load_rom(" & file_name & "): ";

  begin
    -- Ensure G_DATA_WIDTH does not exceed the temporary 'data' width
    assert G_DATA_WIDTH <= data'length
      report report_header & "G_DATA_WIDTH must be <= 16"
      severity failure;

    -- If a non‐empty file name is provided, attempt to open and read it
    if file_name'length > 0 then
      file_open(
        f             => romfile,
        external_name => file_name,
        open_kind     => READ_MODE,
        status        => open_status
      );
      assert open_status = open_ok
        report report_header & "Cannot open ROM file"
        severity failure;

      -- Read until end‐of‐file or a read error
      while not endfile(romfile) and read_ok loop
        readline(romfile, L);
        hread(L, data, read_ok);
        assert read_ok
          report report_header & "Failed to parse data at line " & integer'image(Lnum)
          severity error;

        -- Store the lower G_DATA_WIDTH bits into ROM array
        rom(next_address) := data(G_DATA_WIDTH-1 downto 0);
        next_address     := next_address + 1;
        Lnum             := Lnum + 1;
      end loop;
    end if;

    return rom;
  end function load_rom;

  ---------------------------------------------------------------------------
  -- Constant ROM Initialization
  -- The ROM array is populated at elaboration by calling load_rom.
  ---------------------------------------------------------------------------
  constant ROM : t_rom_array := load_rom(G_ROM_FILE);

begin

  ---------------------------------------------------------------------------
  -- Read Process
  -- On each rising clock edge, either reset the output or present the
  -- signed ROM data corresponding to i_addr.
  ---------------------------------------------------------------------------
  p_read : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        -- Reset output to zero on reset
        o_data <= (others => '0');
      else
        -- Convert std_logic_vector from ROM to signed output
        o_data <= signed( ROM(to_integer(unsigned(i_addr))) );
      end if;
    end if;
  end process p_read;

end architecture rtl;
