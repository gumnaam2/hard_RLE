library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RLE is port (
	clk : in std_logic;
	reset : in std_logic;
	start : in std_logic; -- start filling encoder
	data_in : in std_logic_vector(7 downto 0); -- input matrix data
	data_out : out std_logic_vector(7 downto 0); -- decoded output
	done : out std_logic -- final output done
);
end entity;
architecture rtl of RLE is
----------------------------------------------------------------
-- Encoder signals
----------------------------------------------------------------
signal enc_data_out : std_logic_vector(15 downto 0);
signal enc_done : std_logic;
signal enc_reduced_length : unsigned(7 downto 0); -- widened to 8 bits
----------------------------------------------------------------
-- Decoder signals
----------------------------------------------------------------
signal dec_data_in : std_logic_vector(15 downto 0);
signal dec_start : std_logic;
begin
----------------------------------------------------------------
-- Instantiate RLE Encoder
----------------------------------------------------------------
encoder_inst: entity work.RLE_encoder
port map (
	clk => clk,
	reset => reset,
	start => start,
	data_in => data_in,
	data_out => enc_data_out,
	done => enc_done,
	reduced_length => enc_reduced_length
);
----------------------------------------------------------------
-- Instantiate RLE Decoder
----------------------------------------------------------------
decoder_inst: entity work.RLE_decoder
port map (
	clk => clk,
	reset => reset,
	data_in => dec_data_in,
	start => dec_start, -- decoder start
	reduced_length => enc_reduced_length,
	data_out => data_out,
	done => done
);
----------------------------------------------------------------
-- Connection logic
-- Feed encoder output to decoder
----------------------------------------------------------------
dec_data_in <= enc_data_out;
dec_start <= enc_done; -- decoder starts when encoder asserts done
end architecture;