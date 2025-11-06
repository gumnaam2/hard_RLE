library ieee;
use ieee.std_logic_1164.all;

entity TB2 is
end entity;

architecture sim of TB2 is
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal pass_flag : std_logic;
    signal fail_flag : std_logic;

    -- DUT instance
    component Toplevel is
        port (
            clk        : in  std_logic;
            reset      : in  std_logic;
            pass_flag  : out std_logic;
            fail_flag  : out std_logic
        );
    end component;

begin
    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Reset release
    stim_proc : process
    begin
        wait for 20 ns;
        reset <= '0';
		  wait for 5000 ns;
		  reset <= '1';
		  wait for 20 ns;
		  reset <= '0';
		  wait for 5000 ns;
        wait;  -- let monitor handle stopping
    end process;

    -- Monitor process: ends simulation when flag is set
    monitor_proc : process
    begin
--        loop
--            wait until rising_edge(clk);
--            if pass_flag = '1' then
--                report "TEST PASSED" severity note;
--                assert false report "Simulation finished" severity failure;
--            elsif fail_flag = '1' then
--                report "TEST FAILED" severity error;
--                assert false report "Simulation finished" severity failure;
--            end if;
--        end loop;
		wait for 10000 ns;
		wait;
    end process;

    -- DUT binding
    uut: Toplevel
        port map (
            clk       => clk,
            reset     => reset,
            pass_flag => pass_flag,
            fail_flag => fail_flag
        );

end architecture;
