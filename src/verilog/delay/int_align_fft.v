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
//  Copyright (c) 2018 Kapitanov Alexander
//  Copyright (c) 2023 Benjamin Menkuec
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

module int_align_fft 
    #(
        parameter NFFT  = 16,
        parameter DATW  = 4,
        parameter STAGE = 16
    )
    (
        input                           clk, 
        input       [DATW-1:0]          ia_re,
        input       [DATW-1:0]          ia_im,
        input       [DATW-1:0]          ib_re,
        input       [DATW-1:0]          ib_im,                

        input                           bf_en, 

        output reg  [DATW-1:0]          oa_re, 
        output reg  [DATW-1:0]          oa_im, 
        output reg  [DATW-1:0]          ob_re, 
        output reg  [DATW-1:0]          ob_im, 
        
        output reg                      bf_vl,
        output reg                      tw_en
    );

    generate
        if (STAGE < 11) begin
            
            always @(*) begin
                bf_vl = bf_en;
                oa_re = ia_re;
                oa_im = ia_im;
                ob_re = ib_re;
                ob_im = ib_im;
            end                
        end

        if ((STAGE > 1) & (STAGE < 11)) begin

            if (DATW < 48) begin
                always @(*) begin
                    tw_en = bf_en;
                end
            end else if (DATW > 47) begin
                always @(posedge(clk)) begin
                    tw_en <= bf_en;
                end
            end
        end else if (STAGE > 10) begin
    
            localparam integer ADD_DEL = (DATW < 48) ? 3 : 2;
            reg [DATW-1 : 0] za_re[ADD_DEL : 0];
            reg [DATW-1 : 0] za_im[ADD_DEL : 0];
            reg [DATW-1 : 0] zb_re[ADD_DEL : 0];
            reg [DATW-1 : 0] zb_im[ADD_DEL : 0];
            reg bf_ez [ADD_DEL : 0];  
            
            always @(*) begin
                tw_en = bf_en;
            end 
            
            integer i;
            always @(posedge clk) begin
                for(i = ADD_DEL; i > 0; i = i-1) begin
                    za_re[i] <= za_re[i-1];
                    za_im[i] <= za_im[i-1];
                    zb_re[i] <= zb_re[i-1];
                    zb_im[i] <= zb_im[i-1];
                    bf_ez[i] <= bf_ez[i-1];
                end
                za_re[0] <= ia_re;
                za_im[0] <= ia_im;
                zb_re[0] <= ib_re;
                zb_im[0] <= ib_im;
                bf_ez[0] <= bf_en;
            end

            always @(*) begin
                oa_re = za_re[ADD_DEL];
                oa_im = za_im[ADD_DEL];
                ob_re = zb_re[ADD_DEL];
                ob_im = zb_im[ADD_DEL];
                bf_vl = bf_ez[ADD_DEL];
            end

        end
    endgenerate
endmodule