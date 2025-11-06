library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RLE_decoder is
port (
	clk : in std_logic;
	reset : in std_logic;
	data_in : in std_logic_vector(15 downto 0);
	start : in std_logic;
	reduced_length : in unsigned(7 downto 0);
	data_out : out std_logic_vector(7 downto 0);
	done : out std_logic
);
end entity;

architecture rtl of RLE_decoder is

type mem_t is array (0 to 63) of std_logic_vector(7 downto 0);
signal mem : mem_t;

type rle_t is array (0 to 255) of std_logic_vector(15 downto 0);
signal rle_buffer : rle_t;

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


type fsm_state is (idle, feeding, traversing, returning);
signal state: fsm_state := idle;

signal n_inp, n_out, n_trav : integer range 0 to 64 := 0; --counters

signal mem_write_addr, RLE_write_addr : integer;
signal mem_write_data : std_logic_vector(7 downto 0);
signal RLE_write_data : std_logic_vector(15 downto 0);

signal RLE_index, next_RLE_index, curr_char_n, curr_char_n_D : integer;
begin

state_set: process(clk)
begin
if rising_edge(clk) then
	if reset = '1' then
		state <= idle;
	else
		case state is
			when idle =>
				if start = '1' then
					state <= feeding;
				else
					state <= idle;
				end if;
			when feeding =>
				if n_inp = reduced_length then
					state <= traversing;
				else
					state <= feeding;
				end if;
			when traversing =>
				if n_trav = 63 then
					state <= returning;
				else
					state <= traversing;
				end if;
			when returning =>
				if n_out = 63 then
					state <= feeding;
				else
					state <= returning;
				end if;
			when others =>
				state <= idle;
		end case;
	end if;
end if;
end process;

set_counter: process(clk, reset)
begin
if reset = '1' then
	n_inp <= 0; n_out <= 0; n_trav <= 0;
elsif rising_edge(clk) then
	if (state = feeding) or (state = idle and start = '1') then
		n_inp <= n_inp + 1;
		n_out <= 0; n_trav <= 0;
	elsif state = traversing then
		n_trav <= n_trav + 1;
		n_inp <= 0; n_out <= 0;
	elsif state = returning then
		n_out <= n_out + 1;
		n_inp <= 0; n_trav <= 0;
	else
		n_out <= n_out; n_inp <= n_inp; n_trav <= n_trav;
	end if;
end if;
end process;

reg_proc: process(reset, clk)
begin
if reset = '1' then
	RLE_index <= 0;
	curr_char_n <= 0;
elsif rising_edge(clk) then
	RLE_index <= next_RLE_index;
	curr_char_n <= curr_char_n_D;
end if;
end process;

mem_buf_proc: process(reset, clk) --combined process that manages write to both RLE_buffer and mem
begin
if reset = '1' then
	RLE_buffer <= (others => (others => '0'));
	mem <= (others => (others => '0'));
elsif rising_edge(clk) then
	if (state = feeding) or (state = idle and start = '1') then
		RLE_buffer(RLE_write_addr) <= RLE_write_data;
	elsif state = traversing then
		mem(mem_write_addr) <= mem_write_data;
	end if;
end if;
end process;

mem_set: process(reset, state, start, data_in, n_inp) --write to mem when inputting
begin
if reset = '1' then
	RLE_write_data <= (others => '0');
	RLE_write_addr <= 0;
elsif state = feeding or (state = idle and start = '1') then
	RLE_write_data <= data_in;
	RLE_write_addr <= n_inp;
else
	RLE_write_data <= (others => '0');
	RLE_write_addr <= 0;
end if;
end process;

RLE_load: process(reset, state, n_trav, mem, curr_char_n, RLE_buffer, RLE_index)
begin
if reset = '1' then
	mem_write_addr <= 0;
	mem_write_data <= (others => '0');
	curr_char_n_D <= 0;
	next_RLE_index <= 0;
elsif state = traversing then
	mem_write_addr <= zigzag_order(n_trav);
	report integer'image(n_trav) & ", " & integer'image(zigzag_order(n_trav));
	if curr_char_n < to_integer(unsigned(RLE_buffer(RLE_index)(15 downto 8))) then
		mem_write_data <= RLE_buffer(RLE_index)(7 downto 0);
		curr_char_n_D <= curr_char_n + 1;
		next_RLE_index <= RLE_index;
	else
		mem_write_data <= RLE_buffer(RLE_index + 1)(7 downto 0);
		curr_char_n_D <= 1;
		next_RLE_index <= RLE_index + 1;
	end if;
else
	curr_char_n_D <= 0;
	mem_write_addr <= 0;
	mem_write_data <= (others => '0');
	next_RLE_index <= 0;
end if;
end process;

outp_set: process(n_out, reset, state, RLE_buffer, mem)
begin
if reset = '1' then
	data_out <= (others => '0');
elsif state = returning then
	data_out <= mem(n_out);
else
	data_out <= (others => '0');
end if;
end process;

done_set: process(state, n_trav)
begin
if (state = returning) then
	done <= '1';
else
	done <= '0';
end if;
end process;

end architecture;