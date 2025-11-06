library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Toplevel is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        pass_flag : out std_logic;
        fail_flag : out std_logic
    );
end entity;

architecture rtl of Toplevel is

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal start      : std_logic := '0';
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out   : std_logic_vector(7 downto 0);
    signal done       : std_logic;  -- renamed from out_valid

    ----------------------------------------------------------------
    -- DUT component
    ----------------------------------------------------------------
    component RLE
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            start     : in  std_logic;
            data_in   : in  std_logic_vector(7 downto 0);
            data_out  : out std_logic_vector(7 downto 0);
            done      : out std_logic        -- renamed from out_valid
        );
    end component;

    ----------------------------------------------------------------
    -- Test memory
    ----------------------------------------------------------------
    type data_array is array (0 to 63) of std_logic_vector(7 downto 0);
    signal mem_fill        : data_array;
    signal captured_matrix : data_array;

    ----------------------------------------------------------------
    -- Zigzag LUT
    ----------------------------------------------------------------
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

    ----------------------------------------------------------------
    -- FSM states
    ----------------------------------------------------------------
    type state_t is (INIT, FEED, CAPTURE, CHECK, PASS, FAIL);
    signal state : state_t := INIT;

    signal idx            : integer range 0 to 64 := 0;
    signal capture_count  : integer range 0 to 64 := 0;
    signal mismatch_found : std_logic := '0';

begin

    ----------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------
    dut_inst: RLE
        port map (
            clk       => clk,
            reset     => reset,
            start     => start,
            data_in   => data_in,
            data_out  => data_out,
            done      => done           -- renamed from out_valid
        );

    ----------------------------------------------------------------
    -- FSM
    ----------------------------------------------------------------
    process(clk, reset)
        variable zig_seq : data_array;
        variable idx_var : integer := 0;
    begin
        if reset = '1' then
            state          <= INIT;
            idx            <= 0;
            capture_count  <= 0;
            mismatch_found <= '0';
            pass_flag      <= '0';
            fail_flag      <= '0';
            start          <= '0';
            data_in        <= (others => '0');

        elsif rising_edge(clk) then
            case state is

                ----------------------------------------------------------------
                when INIT =>
                    -- Build zig_seq
                    idx_var := 0;
                    for j in 0 to 3 loop zig_seq(idx_var) := x"41"; idx_var := idx_var+1; end loop;
                    for j in 0 to 2 loop zig_seq(idx_var) := x"43"; idx_var := idx_var+1; end loop;
                    for j in 0 to 5 loop zig_seq(idx_var) := x"42"; idx_var := idx_var+1; end loop;
                    for j in 0 to 4 loop zig_seq(idx_var) := x"44"; idx_var := idx_var+1; end loop;
                    for j in 0 to 1 loop zig_seq(idx_var) := x"41"; idx_var := idx_var+1; end loop;
                    for j in 0 to 6 loop zig_seq(idx_var) := x"42"; idx_var := idx_var+1; end loop;
                    for j in 0 to 7 loop zig_seq(idx_var) := x"43"; idx_var := idx_var+1; end loop;
                    for j in 0 to 2 loop zig_seq(idx_var) := x"44"; idx_var := idx_var+1; end loop;
                    for j in 0 to 5 loop zig_seq(idx_var) := x"41"; idx_var := idx_var+1; end loop;
                    for j in 0 to 4 loop zig_seq(idx_var) := x"42"; idx_var := idx_var+1; end loop;
                    for j in 0 to 7 loop zig_seq(idx_var) := x"43"; idx_var := idx_var+1; end loop;
                    for j in 0 to 6 loop zig_seq(idx_var) := x"41"; idx_var := idx_var+1; end loop;

                    -- Map zigzag sequence back to row-wise
                    for i in 0 to 63 loop
                        mem_fill(zigzag_order(i)) <= zig_seq(i);
                    end loop;

                    idx           <= 0;
                    state         <= FEED;


                ----------------------------------------------------------------
                when FEED =>
                    start   <= '1';
                    data_in <= mem_fill(idx);
                    if idx = 63 then
                        idx   <= 0;
                        state <= CAPTURE;
                    else
                        idx <= idx + 1;
                    end if;

                ----------------------------------------------------------------
                when CAPTURE =>
                    start <= '0';
                    if done = '1' then             -- renamed from out_valid
                        captured_matrix(capture_count) <= data_out;
                        if capture_count = 63 then
                            capture_count <= 0;
                            state <= CHECK;
                        else
                            capture_count <= capture_count + 1;
                        end if;
                    end if;

                ----------------------------------------------------------------
                when CHECK =>
                    if mem_fill(idx) /= captured_matrix(idx) then
                        mismatch_found <= '1';
                    end if;

                    if idx = 63 then
                        if mismatch_found = '1' then
                            state <= FAIL;
                        else
                            state <= PASS;
                        end if;
                        idx <= 0;
                    else
                        idx <= idx + 1;
                    end if;

                ----------------------------------------------------------------
                when PASS =>
                    pass_flag <= '1';
                    fail_flag <= '0';

                when FAIL =>
                    pass_flag <= '0';
                    fail_flag <= '1';

            end case;
        end if;
    end process;

end architecture;
