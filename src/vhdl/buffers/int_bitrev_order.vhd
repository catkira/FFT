-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--  Copyright (c) 2023 Benjamin Menkuec
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
--  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
--  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
--  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
--  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
--  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
-- 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity int_bitrev_order is
    generic (
        PAIR         : boolean:=TRUE;   --! Bitreverse mode: 
                                        --  TRUE - Even/Odd or FALSE - Half Pair
        STAGES       : integer:=11;     --! FFT stages
        NWIDTH       : integer:=16;     --! Data width
        SHIFTED      : integer:=0
    );
    port (
        clk          : in  std_logic;   --! Clock
        reset        : in  std_logic;   --! Reset
        
        di_dt        : in  std_logic_vector(NWIDTH-1 downto 0); --! Data input
        di_en        : in  std_logic;   --! DATA enable

        do_dt        : out std_logic_vector(NWIDTH-1 downto 0); --! Data output    
        do_vl        : out std_logic    --! DATA valid
    );    
end int_bitrev_order;

architecture int_bitrev_order of int_bitrev_order is

function bit_pair(Mode: boolean; Len: integer; Dat: std_logic_vector) return std_logic_vector is
    variable Tmp : std_logic_vector(Len-1 downto 0);
begin 
    if (Mode = TRUE) then
        Tmp(Len-1) :=  Dat(Len-1);
        for ii in 0 to Len-2 loop
            Tmp(ii) := Dat(Len-2-ii);
        end loop;
    else
        for ii in 0 to Len-1 loop
            Tmp(ii) := Dat(Len-1-ii);
        end loop;
    end if;
    if (SHIFTED = 1) then
        Tmp := Tmp + 2**(STAGES-1);
    end if;
    return Tmp; 
end function;

signal cnt_wr         : std_logic_vector(STAGES downto 0); 
signal cnt_rd         : std_logic_vector(STAGES downto 0); 

signal ram_adr_wr     : std_logic_vector(STAGES-1 downto 0);
signal ram_adr_rd     : std_logic_vector(STAGES-1 downto 0);
signal ram_di         : std_logic_vector(NWIDTH-1 downto 0);
signal ram_has_data   : std_logic;
signal ram_has_data_f : std_logic;

signal wea            : std_logic;

type ram_t is array(0 to 2**(STAGES)-1) of std_logic_vector(NWIDTH-1 downto 0);
signal bmem     : ram_t;

begin

------------------- bram vaid data proc ---------------
-- the ram_has_data flag is used to start the output of data
-- even when no new input data is coming, this is necessary
-- to prevent that the last samples are stuck in this module
pr_cnt1: process(clk) is
begin
    if rising_edge(clk) then
        if (reset = '1') then
            ram_has_data <= '0';
        else
            if ((cnt_wr(STAGES-1 downto 0) = 2**STAGES - 1) and di_en = '1') then
                ram_has_data <= '1';
            elsif (cnt_rd(STAGES-1 downto 0) = 2**STAGES - 1) then
                ram_has_data <= '0';
            end if;
        end if;
    end if;
end process;

---------------- Counter proc ----------------
pr_cnt_wr: process(clk) is
begin
    if rising_edge(clk) then
        if (reset = '1') then
            cnt_wr <= (others => '0');
        elsif (di_en = '1') then
            cnt_wr <= cnt_wr + '1';
        end if;
    end if;
end process;

pr_cnt_rd: process(clk) is
begin
    if rising_edge(clk) then
        if (reset = '1') then
            cnt_rd <= (others => '0');
        elsif ((di_en = '1') and ram_has_data = '1') then
                cnt_rd <= cnt_rd + '1';
        elsif (ram_has_data = '1') then
                cnt_rd <= cnt_rd + '1';
        end if;
    end if;
end process;


wea <= di_en when rising_edge(clk);

---------------- Read / Address proc ----------------
pr_adr: process(clk) is
begin
    if rising_edge(clk) then
        if (cnt_wr(cnt_wr'left) = '1') then
            ram_adr_rd <= cnt_rd(STAGES-1 downto 0);
            ram_adr_wr <= cnt_wr(STAGES-1 downto 0);
        else    
            ram_adr_rd <= bit_pair(PAIR, STAGES, cnt_rd);
            ram_adr_wr <= bit_pair(PAIR, STAGES, cnt_wr);
        end if;
    end if;
end process;

---------------- RAM read / write proc ---------------- 
ram_di <= di_dt when rising_edge(clk);
PR_RAM: process(clk) is
begin
    if (clk'event and clk = '1') then
        if (ram_has_data_f = '1') then
            do_dt <= bmem(conv_integer(ram_adr_rd));
        end if;
        if (wea = '1') then
            bmem(conv_integer(ram_adr_wr)) <= ram_di;
        end if;
    end if;    
end process;

---------------- Data out and valid proc ----------------
ram_has_data_f <= ram_has_data when rising_edge(clk);
do_vl <= ram_has_data_f when rising_edge(clk);

end int_bitrev_order;