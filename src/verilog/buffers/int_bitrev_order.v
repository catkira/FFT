// -------------------------------------------------------------------------------
// private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------


module int_bitrev_order #(
    parameter       PAIR = 1,
    parameter       STAGES = 11,
    parameter       NWIDTH = 16,
    parameter       SHIFTED = 0
)
(
    input                           clk,
    input                           rst,

    input           [NWIDTH-1 : 0]  di_dt,
    input                           di_en,

    output  reg     [NWIDTH-1 : 0]  do_dt,
    output  reg                     do_vl
);

function [STAGES-1 : 0] bit_pair;
    input   [STAGES : 0]            Dat;
begin
    integer ii;
    localparam LEN = STAGES;
    if (PAIR) begin
        bit_pair[LEN-1] = Dat[LEN-1];
        for (ii = 0; ii < LEN-1; ii = ii+1)  bit_pair[ii] = Dat[LEN-2-ii];
    end else begin
        for (ii = 0; ii < LEN; ii = ii+1)    bit_pair[ii] = Dat[LEN-1-ii];
    end
    if (SHIFTED) bit_pair = bit_pair + 2**(STAGES-1);
end
endfunction

reg     [STAGES : 0]                cnt_wr;
reg     [STAGES : 0]                cnt_rd;

reg     [STAGES-1 : 0]              ram_adr_wr;
reg     [STAGES-1 : 0]              ram_adr_rd;
reg     [NWIDTH-1 : 0]              di_dt_f;
reg                                 di_en_f;
reg                                 ram_has_data, ram_has_data_f;

reg     [NWIDTH-1 : 0]              bmem  [0 : 2**(STAGES)-1];

// ---------------- bram vaid data proc ---------------
// the ram_has_data flag is used to start the output of data
// even when no new input data is coming, this is necessary
// to prevent that the last samples are stuck in this module
always @(posedge clk) begin
    if (rst)   ram_has_data <= 0;
    else begin
        if ((cnt_wr[STAGES-1 : 0] == 2**STAGES - 1) && di_en)  ram_has_data <= 1;
        else if (cnt_rd[STAGES - 1 : 0] == 2**(STAGES) - 1)    ram_has_data <= 0;
    end
end

// ---------------- Counter proc ---------------------------
always @(posedge clk) begin
    if (rst) begin
        cnt_wr <= 0;
    end else if (di_en) begin
        cnt_wr <= cnt_wr + 1;
    end
end

always @(posedge clk) begin
    if (rst) cnt_rd <= 0;
    // else if (di_en && ram_has_data)         cnt_rd <= cnt_rd + 1;
    else if (ram_has_data)  cnt_rd <= cnt_rd + 1;
end

always @(posedge clk) begin
    ram_adr_wr <= cnt_wr[STAGES] ? cnt_wr[STAGES-1 : 0] : bit_pair(cnt_wr);
    ram_adr_rd <= cnt_wr[STAGES] ? cnt_rd[STAGES-1 : 0] : bit_pair(cnt_rd);
end

// ---------------- RAM read / write proc -------------
always @(posedge clk) begin
    di_en_f <= di_en;
    di_dt_f <= di_dt;    
    
    if (ram_has_data_f)  do_dt <= bmem[ram_adr_rd];
    if (di_en_f)         bmem[ram_adr_wr]   <= di_dt_f;
end

// ---------------- Data out valid proc ---------------
always @(posedge clk) begin
    if (rst) begin
        ram_has_data_f <= '0;
        do_vl <= '0;
    end else begin
        ram_has_data_f <= ram_has_data;
        do_vl <= ram_has_data_f;        
    end
end

endmodule