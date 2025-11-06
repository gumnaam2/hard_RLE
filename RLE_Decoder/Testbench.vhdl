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
    signal data_in        : std_logic_vector(15 downto 0) := (others => '0');
    signal data_out       : std_logic_vector(7 downto 0);
    signal done           : std_logic;
    signal reduced_length : unsigned(7 downto 0);

    constant clk_period : time := 10 ns;

    ----------------------------------------------------------------
    -- DUT component
    ----------------------------------------------------------------
    component RLE_decoder
        port (
            clk            : in  std_logic;
            reset          : in  std_logic;
            start          : in  std_logic;
            data_in        : in  std_logic_vector(15 downto 0);
            reduced_length : in  unsigned(7 downto 0);
            data_out       : out std_logic_vector(7 downto 0);
            done           : out std_logic
        );
    end component;

    ----------------------------------------------------------------
    -- Test arrays
    ----------------------------------------------------------------
    type rle_array  is array (0 to 255) of std_logic_vector(15 downto 0);
    type data_array is array (0 to 63) of std_logic_vector(7 downto 0);

    -- Zigzag LUT
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

    -- Expected 8x8 matrix after decoding
    signal expected_matrix : data_array;
    signal capture_matrix  : data_array := (others => (others => '0'));
    signal out_count       : integer := 0;

    -- RLE test vector (from your encoder TB)
    constant expected_rle_count : integer := 12;
    constant test_rle : rle_array := (
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

begin

    ----------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------
    dut_inst: RLE_decoder
        port map (
            clk            => clk,
            reset          => reset,
            start          => start,
            data_in        => data_in,
            reduced_length => reduced_length,
            data_out       => data_out,
            done           => done
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
    -- Capture output
    ----------------------------------------------------------------
    capture_process : process(clk)
    begin
        if rising_edge(clk) then
            if done = '1' and out_count < 64 then
                capture_matrix(out_count) <= data_out;
                out_count <= out_count + 1;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Stimulus: build expected matrix using explicit run-length loops
    ----------------------------------------------------------------
    stimulus_process : process
        variable zig_seq : data_array;
        variable idx     : integer := 0;
        variable i       : integer;
    begin
        -- Build zig_seq exactly like encoder TB
        idx := 0;
        for i in 0 to 3 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 4xA
        for i in 0 to 2 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 3xC
        for i in 0 to 5 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 6xB
        for i in 0 to 4 loop zig_seq(idx) := x"44"; idx := idx+1; end loop; -- 5xD
        for i in 0 to 1 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 2xA
        for i in 0 to 6 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 7xB
        for i in 0 to 7 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 8xC
        for i in 0 to 2 loop zig_seq(idx) := x"44"; idx := idx+1; end loop; -- 3xD
        for i in 0 to 5 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 6xA
        for i in 0 to 4 loop zig_seq(idx) := x"42"; idx := idx+1; end loop; -- 5xB
        for i in 0 to 7 loop zig_seq(idx) := x"43"; idx := idx+1; end loop; -- 8xC
        for i in 0 to 6 loop zig_seq(idx) := x"41"; idx := idx+1; end loop; -- 7xA

        -- Map zigzag sequence to expected_matrix
        for i in 0 to 63 loop
            expected_matrix(zigzag_order(i)) <= zig_seq(i);
        end loop;

        -- Reset DUT
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait for clk_period;

        -- Feed RLE data
        reduced_length <= to_unsigned(expected_rle_count, 8);
        start <= '1';
        for i in 0 to expected_rle_count-1 loop
            data_in <= test_rle(i);
            wait for clk_period;
        end loop;
        start <= '0';

        -- Wait until all 64 outputs are captured
        wait until out_count = 64;
        wait for clk_period;

        -- Compare outputs
        for i in 0 to 63 loop
            assert capture_matrix(i) = expected_matrix(i)
                report "Mismatch at index " & integer'image(i)
                severity failure;
        end loop;

        report "TEST PASSED: decoder output matches expected zigzag matrix" severity note;
        assert false report "Simulation finished" severity failure;
    end process;

end architecture;
