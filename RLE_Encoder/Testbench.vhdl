library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Testbench is
end entity;

architecture sim of Testbench is

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal start          : std_logic := '0';
    signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out       : std_logic_vector(15 downto 0);
    signal done           : std_logic;
    signal reduced_length : unsigned(7 downto 0);

    constant clk_period : time := 10 ns;

    ----------------------------------------------------------------
    -- DUT component
    ----------------------------------------------------------------
    component RLE_encoder
        port (
            clk            : in  std_logic;
            reset          : in  std_logic;
            start          : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            data_out       : out std_logic_vector(15 downto 0);
            done           : out std_logic;
            reduced_length : out unsigned(7 downto 0)
        );
    end component;

    ----------------------------------------------------------------
    -- Test arrays
    ----------------------------------------------------------------
    type data_array is array (0 to 63) of std_logic_vector(7 downto 0);
    type rle_array  is array (0 to 63) of std_logic_vector(15 downto 0);

    -- Zigzag LUT (same as DUT)
    type zigzag_t is array (0 to 63) of integer range 0 to 63;
    constant zigzag_order : zigzag_t := (
        0, 1, 8,
        16, 9, 2,
        3, 10, 17, 24,
        32, 25, 18, 11, 4,
        5, 12, 19, 26, 33, 40,
        48, 41, 34, 27, 20, 13, 6,
        7, 14, 21, 28, 35, 42, 49, 56,
        57, 50, 43, 36, 29, 22, 15,
        23, 30, 37, 44, 51, 58,
        59, 52, 45, 38, 31,
        39, 46, 53, 60,
        61, 54, 47,
        55, 62,
        63
    );

    -- Expected RLE (12 entries)
    constant expected_rle_count : integer := 12;
    constant expected_rle : rle_array := (
        0  => x"04"&x"41",
        1  => x"03"&x"43",
        2  => x"06"&x"42",
        3  => x"05"&x"44",
        4  => x"02"&x"41",
        5  => x"07"&x"42",
        6  => x"08"&x"43",
        7  => x"03"&x"44",
        8  => x"06"&x"41",
        9  => x"05"&x"42",
        10 => x"08"&x"43",
        11 => x"07"&x"41",
        others => (others => '0')
    );

    signal capture_rle   : rle_array := (others => (others => '0'));
    signal capture_count : integer := 0;


begin

    ----------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------
    dut_inst: RLE_encoder
        port map (
            clk            => clk,
            reset          => reset,
            start          => start,
            data_in        => data_in,
            data_out       => data_out,
            done           => done,
            reduced_length => reduced_length
        );

    ----------------------------------------------------------------
    -- Clock generation
    ----------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk <= '0'; wait for clk_period/2;
            clk <= '1'; wait for clk_period/2;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Capture output until reduced_length is reached
    ----------------------------------------------------------------

	capture_process : process(clk)
	begin
		 if rising_edge(clk) then
			  -- capture one cycle earlier
			  if done = '1' and capture_count < to_integer(reduced_length) then
					capture_rle(capture_count) <= data_out;
					capture_count <= capture_count + 1;
			  end if;
		 end if;
	end process;


    ----------------------------------------------------------------
    -- Stimulus
    ----------------------------------------------------------------
    stimulus_process : process
        variable zig_seq  : data_array;
        variable mem_fill : data_array;
        variable i        : integer;
        variable idx      : integer;
    begin
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait for clk_period;

        -- Build zig_seq from run pattern
        idx := 0;
        for j in 0 to 3 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 4xA
        for j in 0 to 2 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 3xC
        for j in 0 to 5 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 6xB
        for j in 0 to 4 loop zig_seq(idx) := x"44"; idx := idx+1; end loop; -- 5xD
        for j in 0 to 1 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 2xA
        for j in 0 to 6 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 7xB
        for j in 0 to 7 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 8xC
        for j in 0 to 2 loop zig_seq(idx) := x"44"; idx := idx+1; end loop; -- 3xD
        for j in 0 to 5 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 6xA
        for j in 0 to 4 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 5xB
        for j in 0 to 7 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 8xC
        for j in 0 to 6 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 7xA
        assert idx = 64 report "Pattern length mismatch" severity failure;

        -- Map zigzag sequence back to row-wise mem fill
        for i in 0 to 63 loop
            mem_fill(zigzag_order(i)) := zig_seq(i);
        end loop;

        -- Feed DUT row-wise
        start <= '1';

        for i in 0 to 63 loop
            data_in <= mem_fill(i);
            wait for clk_period;
        end loop;
        start <= '0';

        -- Wait until all valid outputs captured
        wait until capture_count = to_integer(reduced_length);
        wait for clk_period;

        -- Check outputs
        for i in 0 to expected_rle_count-1 loop
            assert capture_rle(i) = expected_rle(i)
                report "Mismatch at index " & integer'image(i)
                severity failure;
        end loop;

        report "TEST PASSED: static expected RLE matched" severity note;
        assert false report "Simulation finished" severity failure;
    end process;

end architecture;
