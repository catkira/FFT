// -------------------------------------------------------------------------------
// modifications are private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------

// -------------------------------------------------------------------------------

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//  GNU GENERAL PUBLIC LICENSE
//  Version 3, 29 June 2007
//
//    Copyright (c) 2018 Kapitanov Alexander
//    Copyright (c) 2023 Benjamin Menkuec
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
//  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
//  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
//  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
//  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM  
//  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
//  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//    Version 1.0  29.09.2015
//              Description: Common delay line for FFT    
//                  It is a huge delay line which combines all of delay lines for FFT core
//                  For (N and stage) pair you will see area resources after process of mapping.
//                  SLICEM and LUTs used for short delay lines (shift registers).
//                  SLICEM and LUTs or (RAMB18) used for medium delay lines.
//                  RAMB36 and RAMB18 used for long delay lines.
//
//                 Delay lines: 
//                   NFFT =  2,  N =    4,  delay = 001 - FD,
//                   NFFT =  3,  N =    8,  delay = 002 - 2*FD,
//                   NFFT =  4,  N =   16,  delay = 004 - SLISEM/8 (SRL16),
//                   NFFT =  5,  N =   32,  delay = 008 - SLISEM/4 (SRL16),
//                   NFFT =  6,  N =   64,  delay = 016 - SLISEM/2 (SRL16),
//                   NFFT =  7,  N =  128,  delay = 032 - SLISEM (SRL32),
//                   NFFT =  8,  N =  256,  delay = 064 - 2*SLISEM (CLB/2),
//                   NFFT =  9,  N =  512,  delay = 128 - 4*SLISEM (CLB), 
//                   NFFT = 10,  N =   1K,  delay = 256 - 8*SLISEM (2*CLB), ** OR 4+1 RAMB18E1
//                   NFFT = 11,  N =   2K,  delay = 512 - 4 RAMB18
//                   NFFT = 12,  N =   4K,  delay = 01K - 6 RAMB18
//                   NFFT = 13,  N =   8K,  delay = 02K - 16 RAMB18
//                   NFFT = 14,  N =  16K,  delay = 04K - 32 RAMB18
//                   NFFT = 15,  N =  32K,  delay = 08K - 64 RAMB18
//                   NFFT = 16,  N =  64K,  delay = 16K - 128 RAMB18 
//                   NFFT = 17,  N = 128K,  delay = 32K - 128 RAMB36 
//                   NFFT = 18,  N = 256K,  delay = 64K - 256 RAMB36 etc.
//               
//  Example: NFFT = 4 stages  =>  (N = 2^NFFT = 16 points of FFT).
//           Number of delay line stages: NFFT-1 (from 0 to NFFT-2).
//           Plot time diagrams for stage 0, 1 and 2.
//
//    
// Data enable (input) and data valid (output) strobes take N/2 clock cycles.
// Data for "A" line - 1'st part of FFT data (from 0 to N/2-1)
// Data for "B" line - 2'nd part of FFT data (from N/2 to N-1)
//
// Delay line 0:
// 
// Input:        ________________________
// DI_EN     ___/                        \____
// DI_AA:        /0\/1\/2\/3\/4\/5\/6\/7\
// DI_BB:        \8/\9/\A/\B/\C/\D/\E/\F/
//              ___________
// crx*:    ___|           |________________
//
// Output:              ________________________
// DO_VL            ___/                        \___
// DO_AA:               /0\/1\/2\/3\/8\/9\/A\/B\
// DO_BB:               \4/\5/\6/\7/\C/\D/\E/\F/
//
// Delay line 1: (Input for line 1 = output for line 0)
// 
// Input:        ________________________
// DI_EN     ___/                        \____
// DI_AA:        /0\/1\/2\/3\/8\/9\/A\/B\
// DI_BB:        \4/\5/\6/\7/\C/\D/\E/\F/
//              _____       _____ 
// crx:     ___|     |_____|     |___________
//
// Output:              ________________________
// DO_VL            ___|                        |___
// DO_AA:               /0\/1\/4\/5\/8\/9\/C\/D\
// DO_BB:               \2/\3/\6/\7/\A/\B/\E/\F/
//
//
//
// Delay line 2: (Input for line 2 = output for line 1)
// 
// Input:        ________________________
// DI_EN     ___/                        \____
// DI_AA:        /0\/1\/4\/5\/8\/9\/C\/D\
// DI_BB:        \2/\3/\6/\7/\A/\B/\E/\F/
//              __    __    __    __ 
// crx:     ___|  |__|  |__|  |__|  |_______
//
// Output:              ________________________
// DO_VL            ___/                        \___
// DO_AA:               /0\/2\/4\/6\/8\/A\/C\/E\
// DO_BB:               \1/\3/\5/\7/\9/\B/\D/\F/
//
//
// * - crx signal used for data switching (A and B lines)
// 
// 
//    Version 1.5  11.05.2018 
//               Delay line scheme (+ example):
//                     
//         |           |             |            | 
//         |   _____   |    ______   |            | 
//         |  |     |  |   | MUXD |  |            | 
// DI_BB --|->| N/4 |--|-->|------>--|------------|--> DO_BB
//         |  |_____|  |   | \  / |  |            | 
//         |           |   |  \/  |  |            | 
//         |           |   |  /\  |  |    _____   |    
//         |           |   | /  \ |  |   |     |  | 
// DI_AA --|-----------|-->|------>--|-->| N/4 |--|--> DO_AA
//         |           |   |______|  |   |_____|  | 
//         |           |             |            | 
//         |           |             |            | 
//         X0          X1            X2           X3
//
//
// Input data:       ________________________
// ENABLE        ___/                        \____
// X0_AA:            /0\/1\/2\/3\/4\/5\/6\/7\
// X0_BB:            \8/\9/\A/\B/\C/\D/\E/\F/
//               
// Delay B line:          
// X1_AA:            /0\/1\/2\/3\/4\/5\/6\/7\
// X1_BB:                        \8/\9/\A/\B/\C/\D/\E/\F/
//               
// Multiplexing:       
// X2_AA:            /0\/1\/2\/3\/8\/9\/A\/B\
// X2_BB:                        \4/\5/\6/\7/\C/\D/\E/\F/
//                   
// Delay A line (Output):        ________________________
// VALID                     ___/                        \____
// X3_AA:                        /0\/1\/2\/3\/8\/9\/A\/B\
// X3_BB:                        \4/\5/\6/\7/\C/\D/\E/\F/
//                    
//


module int_delay_line #(
    parameter 
    NFFT   = 16,
    NWIDTH = 4,
    STAGE  = 16
)
(
    input                       clk,
    input                       rst,
    input       [NWIDTH-1:0]    di_aa,
    input       [NWIDTH-1:0]    di_bb,
    input                       di_en, 


    output reg  [NWIDTH-1:0]    do_aa,
    output reg  [NWIDTH-1:0]    do_bb,
    output reg                  do_vl
);

localparam integer N_INV = NFFT-STAGE-2; 

generate
if (N_INV == 0) begin : xZERO 
    reg                     cross_;  // cross is a systemverilog 2005 reserved word
    reg  [NWIDTH-1 : 0]     di_az;
    reg  [NWIDTH-1 : 0]     di_bz;
    reg                     di_ez;

    always @(posedge clk) begin
        if (rst)  cross_ <= 0;
        else if (di_en)  cross_ <= !cross_;
    end

    always @(posedge clk) begin
        di_az <= cross_ ? di_bz : di_aa;
        do_bb <= cross_ ? di_aa : di_bz;
    end

    always @(posedge clk) begin
        do_aa <= di_az;
        do_vl <= di_ez;

        di_bz <= di_bb;
        di_ez <= di_en;
    end

end
endgenerate

generate
if (N_INV > 0) begin : xSTAGES
    reg                     cross_;  // cross is a systemverilog 2005 reserved word
    reg     [N_INV : 0]     cnt_adr;
    reg     [N_INV-1 : 0]   cnt_ptr;
    reg     [N_INV-1 : 0]   cnt_del;

    reg     [NWIDTH-1 : 0]  bram0  [0 : (2**N_INV)-1];
    reg     [NWIDTH-1 : 0]  bram1  [0 : (2**N_INV)-1];

    reg     [NWIDTH-1 : 0]  ram0_di;
    reg     [NWIDTH-1 : 0]  ram0_do;
    reg     [NWIDTH-1 : 0]  ram1_di;
    reg     [NWIDTH-1 : 0]  ram1_do;

    wire    [N_INV-1 : 0]   add0_rd;
    reg     [N_INV-1 : 0]   add0_wr;
    reg     [N_INV-1 : 0]   add1_rd;
    reg     [N_INV-1 : 0]   add1_wr;

    wire                    ram0_rd;
    reg                     ram0_we;
    reg                     ram1_rd;
    reg                     ram1_we;

    reg                     ram_we;

    reg     [N_INV : 0]     cnt_trd;
    reg     [N_INV : 0]     cnt_twr;
    reg                     cnt_ena;

    reg     [NWIDTH-1 : 0]  di_az;

    always @(posedge clk) begin
        if      (rst)    cnt_adr <= 0;
        else if (di_en)  cnt_adr <= cnt_adr + 1;
    end

    always @(posedge clk) begin
        if      (rst)      cnt_ptr <= 0;
        else if (cnt_ena)  cnt_ptr <= cnt_ptr + 1;
    end

    always @(posedge clk)  di_az <= di_aa;
    // ---- Cross-commutation ----
    always @(posedge clk) begin
        ram1_di <= cross_ ? ram0_do : di_az;
        do_bb   <= cross_ ? di_az : ram0_do;
    end
    always @(posedge clk)  cross_ <= cnt_adr[N_INV];

    always @(posedge clk) begin
        if (rst) begin
            cnt_trd <= 1'b1;
            cnt_twr <= 1'b1;
            cnt_ena <= 0;
        end else begin
            // ---- @write data ----            
            if (cnt_trd[N_INV]) begin
                cnt_trd <= 1'b1;
            end else begin
                if (di_en)  cnt_trd <= cnt_trd + 1;
            end
            // ---- delayed data enable ----
            if (cnt_trd[N_INV])  cnt_ena <= 1'b1;
            else if (cnt_twr[N_INV])  cnt_ena <= 0;
            // ---- @read data ----
            if (cnt_twr[N_INV]) cnt_twr <= 1'b1;
            else if (cnt_ena)  cnt_twr <= cnt_twr + 1;
        end
    end

    assign ram0_di = di_bb;

    // ---- RAM Write enable ----
    always @(posedge clk) begin
        ram_we <= di_en;
        ram1_we <= ram_we;
    end
    assign ram0_we = di_en;

    // ---- Address write ----
    always @(posedge clk) begin
        cnt_del <= cnt_adr;
        add1_wr <= cnt_del;
    end
    always @(*)  add0_wr = cnt_adr;

    // ---- RAM Read enable ----
    always @(posedge clk) begin
        ram1_rd <= cnt_ena;
        add1_rd <= cnt_ptr;
    end
    assign ram0_rd = cnt_ena;
    assign add0_rd = cnt_ptr;

    //assign do_aa = ram1_do; // assign to reg is same as always @(*)
    always @(*)  do_aa = ram1_do;
    always @(posedge clk)  do_vl <= ram1_rd;

    // ------------ First RAMB delay line ------------ 
    always @(posedge clk) begin
        if (ram0_we)  bram0[add0_wr] <= ram0_di;
        if (ram0_rd)  ram0_do <= bram0[add0_rd];
    end

    // ------------ Second RAMB delay line ------------
    always @(posedge clk) begin
        if (ram1_we)  bram1[add1_wr] <= ram1_di;
        if (ram1_rd)  ram1_do <= bram1[add1_rd];
    end

end
endgenerate


endmodule