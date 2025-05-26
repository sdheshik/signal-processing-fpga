library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.TEXTIO.ALL;

-------------------------------------------------------------------------------
-- Entity: rom_square
-- ROM‐based square‐wave lookup table. At elaboration, reads a text file of
-- 16‐bit words into a constant ROM array indexed by a G_ADDR_WIDTH‐bit address.
-------------------------------------------------------------------------------
entity rom_square is
  generic (
    G_ROM_FILE   : string   := "square.rom";       -- Path/name of the ROM init file
    G_ADDR_WIDTH : positive := 9;                  -- Address bus width (depth = 2**G_ADDR_WIDTH)
    G_DATA_WIDTH : positive := 16                  -- Data word width
  );
  port (
    clk    : in  std_logic;                                    -- System clock
    rst_n  : in  std_logic;                                    -- Active‐low synchronous reset
    i_addr : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);    -- Read address
    o_data : out signed(G_DATA_WIDTH-1 downto 0)                -- Output data word (signed)
  );
end entity rom_square;

-------------------------------------------------------------------------------
-- Architecture: rtl
-------------------------------------------------------------------------------
architecture rtl of rom_square is

  ---------------------------------------------------------------------------
  -- Type Declaration: ROM array
  -- An array of 2**G_ADDR_WIDTH entries, each G_DATA_WIDTH bits wide.
  ---------------------------------------------------------------------------
  type t_rom_array is
    array (0 to 2**G_ADDR_WIDTH-1) of
          std_logic_vector(G_DATA_WIDTH-1 downto 0);

  ---------------------------------------------------------------------------
  -- Function: load_rom
  -- Impure function reads a text file at elaboration time into a ROM array.
  ---------------------------------------------------------------------------
  impure function load_rom(
      constant file_name : in string
    ) return t_rom_array is

    file                     romfile       : text;                      -- File handle
    variable rom             : t_rom_array;                               -- Local ROM storage
    variable open_status     : file_open_status := NAME_ERROR;           -- File open status
    variable L               : line;                                     -- TextIO line buffer
    variable Lnum            : natural := 0;                              -- Line counter
    variable read_ok         : boolean := true;                           -- HREAD success flag
    variable next_address    : integer := 0;                              -- Write pointer
    variable data            : std_logic_vector(15 downto 0);            -- Temp data buffer
    constant report_header   : string := "load_rom(" & file_name & "): ";-- Assertion prefix

  begin
    -- Ensure G_DATA_WIDTH does not exceed the temporary buffer width
    assert G_DATA_WIDTH <= data'length
      report report_header & "G_DATA_WIDTH must be <= 16"
      severity failure;

    if file_name'length > 0 then
      -- Open ROM file for reading
      file_open(
        f             => romfile,
        external_name => file_name,
        open_kind     => READ_MODE,
        status        => open_status
      );
      assert open_status = open_ok
        report report_header & "Cannot open ROM file"
        severity failure;

      -- Read until EOF or parse error
      while not endfile(romfile) and read_ok loop
        readline(romfile, L);
        hread(L, data, read_ok);
        assert read_ok
          report report_header & "Failed to parse data at line " & integer'image(Lnum)
          severity error;

        -- Store lowest G_DATA_WIDTH bits into ROM
        rom(next_address) := data(G_DATA_WIDTH-1 downto 0);
        next_address     := next_address + 1;
        Lnum             := Lnum + 1;
      end loop;
    end if;

    return rom;
  end function load_rom;

  ---------------------------------------------------------------------------
  -- Constant ROM Initialization
  -- Populated at elaboration by calling load_rom.
  ---------------------------------------------------------------------------
  constant ROM : t_rom_array := load_rom(G_ROM_FILE);

begin

  ---------------------------------------------------------------------------
  -- Read Process
  -- On each rising clock edge, reset output or present signed ROM data.
  ---------------------------------------------------------------------------
  p_read : process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        -- Clear output on reset
        o_data <= (others => '0');
      else
        -- Index ROM and convert to signed
        o_data <= signed( ROM(to_integer(unsigned(i_addr))) );
      end if;
    end if;
  end process p_read;

end architecture rtl;
