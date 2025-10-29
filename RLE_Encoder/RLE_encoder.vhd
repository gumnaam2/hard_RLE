library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RLE_encoder is port (
	clk : in std_logic;
	reset : in std_logic;
	start : in std_logic;
	data_in : in std_logic_vector(7 downto 0);
	data_out : out std_logic_vector(15 downto 0);
	done : out std_logic;
	reduced_length : out unsigned(7 downto 0)
);
end entity;

architecture arch of RLE_encoder is
----------------------------------------------------------------
-- Matrix storage
----------------------------------------------------------------
type mem_t is array (0 to 63) of std_logic_vector(7 downto 0);
signal mem : mem_t;
----------------------------------------------------------------
-- Zigzag order for 8 x 8 matrix
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

type rle_t is array (0 to 63) of std_logic_vector(15 downto 0);
signal rle_buffer : rle_t;
signal x : std_logic;
type fsm_state is (feeding, traversing, returning);
signal state: fsm_state := feeding;

signal n_inp, n_out, n_trav : integer range 0 to 64 := 0;

signal reduced_length_reg, reduced_length_reg_D: integer range 0 to 64 := 0;

signal addr_reg, addr_reg_D, curr_char_n, curr_char_n_D : integer;
signal curr_char_reg, curr_char_reg_D : std_logic_vector(7 downto 0);
signal mem_write_addr, RLE_write_addr : integer;
signal mem_write_data : std_logic_vector(7 downto 0);
signal RLE_write_data : std_logic_vector(15 downto 0);

begin

state_set: process(clk, reset)
begin
if reset = '1' then
	state <= feeding;
elsif rising_edge(clk) then
--	if state = idle then
--		if start = '1' then
--			state <= feeding;
--		end if;
	if state = feeding then
		if n_inp = 63 and start = '1' then
			state <= traversing;
		end if;
	elsif state = traversing then
		if n_trav = 63 then
			state <= returning;
		else
			state <= traversing;
		end if;
	elsif state = returning then
		if n_out = 63 then
			state <= feeding;
		end if;
	end if;
end if;
end process;

set_counter: process(clk, reset)
begin
if reset = '1' then
	n_inp <= 0; n_out <= 0; n_trav <= 0;
elsif rising_edge(clk) then
	if state = feeding and start = '1' then
		n_inp <= n_inp + 1;
		n_out <= 0; n_trav <= 0;
	elsif state = traversing then
		n_trav <= n_trav + 1;
		n_inp <= 0; n_out <= 0;
	else
		n_out <= n_out + 1;
		n_inp <= 0; n_trav <= 0;
	end if;
end if;
end process;

reg_proc: process(reset, clk)
begin
if reset = '1' then
	addr_reg <= 0;
	curr_char_reg <= (others => '0');
	curr_char_n <= 0;
elsif rising_edge(clk) then
	addr_reg <= addr_reg_D;
	curr_char_reg <= curr_char_reg_D;
	curr_char_n <= curr_char_n_D;
end if;
end process;

mem_buf_proc: process(reset, clk) --combined process that manages write to both RLE_buffer and mem
begin
if reset = '1' then
	RLE_buffer <= (others => (others => '0'));
	mem <= (others => (others => '0'));
elsif rising_edge(clk) then
	if state = feeding and start = '1' then
		mem(mem_write_addr) <= mem_write_data;
	elsif state = traversing then
		RLE_buffer(RLE_write_addr) <= RLE_write_data;
		reduced_length_reg <= reduced_length_reg_D;
	end if;
end if;
end process;

--mem_write: process(reset, clk)
--begin
--if reset = '1' then
--	mem <= (others => (others => '0'));
--elsif rising_edge(clk) then
--	if state = feeding then
--		mem(n_inp) <= data_in;
--		x <= '1';
--	end if;
--end if;
--end process;
--

mem_set: process(reset, state, data_in, n_inp) --write to mem when inputting
begin
if reset = '1' then
	mem_write_data <= (others => '0');
	mem_write_addr <= 0;
elsif state = feeding and start = '1' then
	mem_write_data <= data_in;
	mem_write_addr <= n_inp;
else
	mem_write_data <= (others => '0');
	mem_write_addr <= 0;
end if;
end process;

RLE_load: process(reset, state, n_trav, mem, curr_char_reg, curr_char_n, addr_reg)
begin
if reset = '1' then
	RLE_write_addr <= 0;
	RLE_write_data <= (others => '0');
	curr_char_reg_D <= (others => '0');
	curr_char_n_D <= 0;
	reduced_length_reg_D <= 0;
elsif state = traversing then
	report integer'image(n_trav) & " " & integer'image(to_integer(unsigned(mem(zigzag_order(n_trav)))));
	if mem(zigzag_order(n_trav)) = curr_char_reg then
		RLE_write_addr <= reduced_length_reg - 1;
		reduced_length_reg_D <= reduced_length_reg;
		
		RLE_write_data(7 downto 0) <= curr_char_reg;
		RLE_write_data(15 downto 8) <= std_logic_vector(to_unsigned(curr_char_n + 1, 8));
		
		curr_char_reg_D <= curr_char_reg;
		curr_char_n_D <= curr_char_n + 1;
	else
		RLE_write_data(7 downto 0) <= mem(zigzag_order(n_trav));
		RLE_write_data(15 downto 8) <= "00000001";
		
		RLE_write_addr <= reduced_length_reg;
		reduced_length_reg_D <= reduced_length_reg + 1;

		curr_char_reg_D <= mem(zigzag_order(n_trav));
		curr_char_n_D <= 1;

	end if;
else
	RLE_write_addr <= 0;
	RLE_write_data <= (others => '0');
	curr_char_reg_D <= (others => '0');
	curr_char_n_D <= 0;
	reduced_length_reg_D <= reduced_length_reg;
end if;
end process;

outp_set: process(n_out, reset, state, RLE_buffer)
begin
if reset = '1' then
	data_out <= (others => '0');
elsif state = returning then
	data_out <= RLE_buffer(n_out);
else
	data_out <= (others => '0');
end if;
end process;

reduced_length <= to_unsigned(reduced_length_reg, 8);

done_set: process(state, n_trav, addr_reg)
begin
if (state = returning) then
	done <= '1';
--	reduced_length <= to_unsigned(addr_reg, 8);
else
	done <= '0';
--	reduced_length <= (others => '0');
end if;
end process;

end architecture;