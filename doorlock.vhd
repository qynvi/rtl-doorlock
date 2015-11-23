-- qynvi
-- 02/14/2011
-- RTL for a door locking asic

-- Base Features:
-- * Idle LED Red
-- * Unlock LED Green
-- * Accepts any 3 inputs, then unlocks on specific correct sequence
-- * Automatic re-idle, code entry time limit of 3 seconds total

-- Additional Features:
-- * Software reset and wrong input LED
-- * Never goes idle if button is held down
-- * Supports simultaneous keypresses
-- * Supports separate keypress and unlock time limit windows

library ieee;
use ieee.std_logic_1164.all;

entity doorlock is
	generic (
			 -- set a modular time limit for key entry
			 tlimit: integer := 150_000_000; -- 3 seconds
			 -- set the amount of time it stays unlocked
			 ulimit: integer := 150_000_000; -- 3 seconds
			 -- use a bit vector to mask the buttons, 1(switch)-2-3-4-5
			 -- the right code sequence is 4-3-2 on the lock and can be modified as a generic here
			 secret1: std_logic_vector(4 downto 0) := "01101";
			 secret2: std_logic_vector(4 downto 0) := "01011";
			 secret3: std_logic_vector(4 downto 0) := "00111";
			 nokey: std_logic_vector(4 downto 0) := "01111");
	port (clk,rst,key1,key2,key3,key4,key5: in std_logic;
		  led_idle,led_unlock,led_reset: out std_logic);
end doorlock;

architecture dl of doorlock is
	type state is (idle,wait1,push2,wait2,push3,wait3,verify,reset,unlock);
	signal pr_state,nx_state: state;
	attribute enum_encoding: string;
	attribute enum_encoding of state: type is "sequential";
	signal kp: std_logic_vector(4 downto 0);
	shared variable cv: natural range 0 to tlimit := 1;
	shared variable kcounter: natural range 0 to tlimit := 0;

begin

	kp <= (key1 & key2 & key3 & key4 & key5);

	process (clk,rst)
	begin
		if (rst='1') then
			pr_state <= idle;
			kcounter := 0;
		elsif (clk'event and clk='1') then
			kcounter := kcounter + 1;
			if (kcounter>=cv) then
				pr_state <= nx_state;
				kcounter := 0;
			end if;
		end if;
	end process;

	process (pr_state,kp)

	-- Need to wait to tell the user they are wrong no matter
	-- what three buttons they press therefore track with
	-- three variables, masked with the input, using a
	-- temporary buffer vector

	variable input1: std_logic_vector(4 downto 0) := "00000";
	variable input2: std_logic_vector(4 downto 0) := "00000";
	variable input3: std_logic_vector(4 downto 0) := "00000";
	variable temp: std_logic_vector(4 downto 0);

	begin
		case pr_state is

			when idle =>
				led_idle <= '1';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				if (kp/=nokey) then
					-- immediately store the keypress
					temp := kp;
					cv := 0;
					nx_state <= wait1;
				else
					nx_state <= idle;
				end if;

			when wait1 =>
				cv := tlimit;
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				if (kp=nokey) then
					-- store input iff user releases the key
					input1 := temp;
					-- force next state
					cv := 0;
					nx_state <= push2;
				elsif (kp=temp) then
					-- if they're spamming the button, loop the wait state
					cv := 0;
					nx_state <= wait1;
				else
					-- if somehow the debouncer failed, default return to idle after a while
					nx_state <= reset;
				end if;

			when push2 =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				if (kp/=nokey) then
					temp := kp;
					cv := 0;
					nx_state <= wait2;
				else
					nx_state <= reset;
				end if;

			when wait2 =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				if (kp=nokey) then
					input2 := temp;
					cv := 0;
					nx_state <= push3;
				elsif (kp=temp) then
					cv := 0;
					nx_state <= wait2;
				else
					nx_state <= reset;
				end if;

			when push3 =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				if (kp/=nokey) then
					temp := kp;
					cv := 0;
					nx_state <= wait3;
				else
					nx_state <= reset;
				end if;

			when wait3 =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				if (kp=nokey) then
					input3 := temp;
					cv := 0;
					nx_state <= verify;
				elsif (kp=temp) then
					cv := 0;
					nx_state <= wait3;
				else
					nx_state <= reset;
				end if;

			when verify =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '0';
				cv := tlimit;
				-- this is the easiest way to check the code without imposing
				-- a limit on how long the CPU can take to evaluate the inputs
				if (input3=secret3) then
					if (input2=secret2) then
						if (input1=secret1) then
							cv := 0;
							nx_state <= unlock;
						else
							cv := 0;
							nx_state <= reset;
						end if;
					else
						cv := 0;
						nx_state <= reset;
					end if;
				else
					cv := 0;
					nx_state <= reset;
				end if;

			when reset =>
				led_idle <= '0';
				led_unlock <= '0';
				led_reset <= '1';
				cv := tlimit;
				nx_state <= idle;

			when unlock =>
				led_idle <= '0';
				led_unlock <= '1';
				led_reset <= '0';
				cv := ulimit;
				nx_state <= reset;

		end case;
	end process;
end architecture;
