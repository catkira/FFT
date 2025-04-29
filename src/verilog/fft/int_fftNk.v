// -------------------------------------------------------------------------------
// modifications are private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------

// -------------------------------------------------------------------------------

// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------
// --
// --  GNU GENERAL PUBLIC LICENSE
// --  Version 3, 29 June 2007
// --
// --  Copyright (c) 2018 Kapitanov Alexander
// --
// --  This program is free software: you can redistribute it and/or modify
// --  it under the terms of the GNU General Public License as published by
// --  the Free Software Foundation, either version 3 of the License, or
// --  (at your option) any later version.
// --
// --  You should have received a copy of the GNU General Public License
// --  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// --
// --  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
// --  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
// --  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
// --  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
// --  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
// --  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
// --  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
// --  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
// -- 
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------

module int_fftNk #(
    parameter       NFFT = 5,
    parameter       FORMAT = 1,             //  1 - Unscaled, 0 - Scaled
    parameter       RNDMODE = 0,            //  0 - Truncate, 1 - Rounding (FORMAT should be = 1)
    parameter       DATA_WIDTH = 16,        //  Input data width
    parameter       TWDL_WIDTH = 16,        //  Twiddle factor data width  
    parameter       XSER = "OLD",           //  FPGA family: for 6/7 series: "OLD"; for ULTRASCALE: "NEW";
    parameter       USE_MLT = 0             //  Use multipliers in Twiddle factors
)
(
    input                                   rst,        //  Global positive RST
    input                                   clk,

    input                                   USE_FLY,    //  '1' - use arithmetics, '0' - don't use

    input   [DATA_WIDTH-1 : 0]              DI_RE0,
    input   [DATA_WIDTH-1 : 0]              DI_IM0,
    input   [DATA_WIDTH-1 : 0]              DI_RE1,
    input   [DATA_WIDTH-1 : 0]              DI_IM1,
    input                                   DI_ENA,

    output  reg [FORMAT*NFFT+DATA_WIDTH-1 : 0]  DO_RE0,
    output  reg [FORMAT*NFFT+DATA_WIDTH-1 : 0]  DO_IM0,
    output  reg [FORMAT*NFFT+DATA_WIDTH-1 : 0]  DO_RE1,
    output  reg [FORMAT*NFFT+DATA_WIDTH-1 : 0]  DO_IM1,
    output  reg                                 DO_VAL
);

localparam  SCALE = (FORMAT == 0) ? 1 : 0;

// -------- Butterfly In / Out --------
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ia_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ia_im   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ib_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ib_im   [0 : NFFT-1];

wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      oa_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      oa_im   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ob_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      ob_im   [0 : NFFT-1];

// -------- Align data --------
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      sa_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      sa_im   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      sb_re   [0 : NFFT-1];
wire    [FORMAT*NFFT+DATA_WIDTH-1 : 0]      sb_im   [0 : NFFT-1];

// -------- Mux'ed data flow (fly_ena) --------
reg     [FORMAT*NFFT+DATA_WIDTH-1 : 0]      xa_re   [0 : NFFT-1];
reg     [FORMAT*NFFT+DATA_WIDTH-1 : 0]      xa_im   [0 : NFFT-1];
reg     [FORMAT*NFFT+DATA_WIDTH-1 : 0]      xb_re   [0 : NFFT-1];
reg     [FORMAT*NFFT+DATA_WIDTH-1 : 0]      xb_im   [0 : NFFT-1];

// -------- Enables --------
wire    [NFFT-1 : 0]                        ab_en;                      
wire    [NFFT-1 : 0]                        ab_vl;                      
wire    [NFFT-1 : 0]                        ss_en;                      
reg     [NFFT-1 : 0]                        xx_vl;

// -------- Delay data Cross-commutation -----                 ---
wire    [FORMAT*2*NFFT+2*DATA_WIDTH-1 : 0]  di_aa   [0 : NFFT-2];
wire    [FORMAT*2*NFFT+2*DATA_WIDTH-1 : 0]  di_bb   [0 : NFFT-2];
wire    [FORMAT*2*NFFT+2*DATA_WIDTH-1 : 0]  do_aa   [0 : NFFT-2];
wire    [FORMAT*2*NFFT+2*DATA_WIDTH-1 : 0]  do_bb   [0 : NFFT-2];

wire    [NFFT-2 : 0]                        di_en;
wire    [NFFT-2 : 0]                        do_en;

// -------- Twiddle factor --------
wire    [TWDL_WIDTH-1 : 0]                  ww_re   [0 : NFFT - 1];
wire    [TWDL_WIDTH-1 : 0]                  ww_im   [0 : NFFT - 1];
wire    [NFFT-1 : 0]                        ww_en;

assign ab_en[0] = DI_ENA;
assign ia_re[0] = DI_RE0;
assign ia_im[0] = DI_IM0;
assign ib_re[0] = DI_RE1;
assign ib_im[0] = DI_IM1;

initial $display("NFFT = %d", NFFT);

genvar ii;
for (ii = 0; ii < NFFT; ii = ii+1) begin
    int_dif2_fly#(
        .SCALE(SCALE),
        .RNDMODE(RNDMODE),
        .STAGE(NFFT-ii-1),
        .DTW(DATA_WIDTH+ii*FORMAT),
        .TFW(TWDL_WIDTH),
        .XSER(XSER)
    )
    xBUTTERFLY(
        .ia_re(sa_re[ii]),
        .ia_im(sa_im[ii]),
        .ib_re(sb_re[ii]),
        .ib_im(sb_im[ii]),
        .in_en(ss_en[ii]),

        .oa_re(oa_re[ii]),
        .oa_im(oa_im[ii]),
        .ob_re(ob_re[ii]),
        .ob_im(ob_im[ii]),
        .do_vl(ab_vl[ii]),

        .ww_re(ww_re[ii]),
        .ww_im(ww_im[ii]),
        
        .rst(rst),
        .clk(clk)
    );

    // ---- Twiddle factor ----
    rom_twiddle_int #(
        .AWD(TWDL_WIDTH),
        .NFFT(NFFT),
        .STAGE(NFFT-ii-1),
        .XSER(XSER),
        .USE_MLT(USE_MLT)
    )
    xTWIDDLE(
        .rst(rst),
        .clk(clk),
        .ww_en(ww_en[ii]),
        .ww_re(ww_re[ii]),
        .ww_im(ww_im[ii])
    );

    // ---- Aligne data for butterfly calc ----
    int_align_fft #(
        .DATW(DATA_WIDTH+ii*FORMAT),
        .NFFT(NFFT),
        .STAGE(NFFT-ii-1)
    )
    xALIGNE(
        .clk(clk),
        .ia_re(ia_re[ii]),
        .ia_im(ia_im[ii]),
        .ib_re(ib_re[ii]),
        .ib_im(ib_im[ii]),

        .oa_re(sa_re[ii]),
        .oa_im(sa_im[ii]),
        .ob_re(sb_re[ii]),
        .ob_im(sb_im[ii]),

        .bf_en(ab_en[ii]),
        .bf_vl(ss_en[ii]),
        .tw_en(ww_en[ii])
    );

    // ---- select input delay data ----
    always @(posedge clk) begin
        if (USE_FLY) begin
            xx_vl[ii] <= ab_vl[ii];
            xa_re[ii] <= oa_re[ii];
            xa_im[ii] <= oa_im[ii];
            xb_re[ii] <= ob_re[ii];
            xb_im[ii] <= ob_im[ii];        
        end else begin
            xx_vl[ii] <= ab_en[ii];
            xa_re[ii] <= ia_re[ii];
            xa_im[ii] <= ia_im[ii];
            xb_re[ii] <= ib_re[ii];
            xb_im[ii] <= ib_im[ii];
        end
    end
end

for (ii = 0; ii < NFFT-1; ii = ii+1) begin : xDELAYS
    localparam DW = (DATA_WIDTH+(ii+1)*FORMAT);

    assign di_aa[ii] = {xa_im[ii][DW-1 : 0], xa_re[ii][DW-1 : 0]};
    assign di_bb[ii] = {xb_im[ii][DW-1 : 0], xb_re[ii][DW-1 : 0]};
    assign di_en[ii] = xx_vl[ii];

    int_delay_line #(
        .NWIDTH(2*DW),
        .NFFT(NFFT),
        .STAGE(ii)
    )
    xDELAY_LINE(
        .di_aa(di_aa[ii]),
        .di_bb(di_bb[ii]),
        .di_en(di_en[ii]),
        .do_aa(do_aa[ii]),
        .do_bb(do_bb[ii]),
        .do_vl(do_en[ii]),
        .rst(rst),
        .clk(clk)
    );

    assign ia_re[ii+1] = do_aa[ii][1*DW-1 : 0*DW];
    assign ia_im[ii+1] = do_aa[ii][2*DW-1 : 1*DW];
    assign ib_re[ii+1] = do_bb[ii][1*DW-1 : 0*DW];
    assign ib_im[ii+1] = do_bb[ii][2*DW-1 : 1*DW];
    assign ab_en[ii+1] = do_en[ii];
end

always @(posedge clk) begin
    DO_RE0 <= xa_re[NFFT-1];
    DO_IM0 <= xa_im[NFFT-1]; 
    DO_RE1 <= xb_re[NFFT-1]; 
    DO_IM1 <= xb_im[NFFT-1]; 
    DO_VAL <= xx_vl[NFFT-1];
end

endmodule
