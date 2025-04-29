// -------------------------------------------------------------------------------
// modifications are private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------

module dynamic_block_scaling #(
    parameter       STAGES = 10,
    parameter       NWIDTH = 16
)
(
    input                                           clk_i,
    input                                           reset_i,

    input           [NWIDTH-1 : 0]                  di_dt,
    input                                           di_vl,

    output  reg     [NWIDTH-1 : 0]                  do_dt,
    output  reg     [$clog2(NWIDTH / 2) - 1 : 0]    blk_exp_o,
    output  reg                                     do_vl
);

reg     [STAGES : 0]                reg1;
reg     [STAGES : 0]                reg2;
reg                                 reg3;

reg     [NWIDTH-1 : 0]              reg4;
reg                                 reg5;
reg                                 reg6, reg6_f;

reg     [NWIDTH-1 : 0]              bmem  [0 : 2**(STAGES)-1];

reg     [$clog2(NWIDTH / 2) - 1 : 0]        mmp [0 : 1];

wire     [$clog2(NWIDTH / 2) - 1 : 0]       mmp_0 = mmp[0];
wire     [$clog2(NWIDTH / 2) - 1 : 0]       mmp_1 = mmp[1];

always @(posedge clk_i) begin
    if (reset_i)   reg6 <= 0;
    else begin
        if ((reg1[STAGES-1 : 0] == 2**STAGES - 1) && di_vl)  reg6 <= 1;
        else if (reg2[STAGES - 1 : 0] == 2**(STAGES) - 1)    reg6 <= 0;
    end
end

always @(posedge clk_i) begin
    if (reset_i) begin
        reg1 <= 0;
    end else if (di_vl) begin
        reg1 <= reg1 + 1;
    end
end

always @(posedge clk_i) begin
    if (reset_i) begin
        reg2 <= 0;
        reg3 <= 0;
    end else if (reg6) begin
        reg2 <= reg2 + 1;
        reg3 <= reg2[STAGES];
    end
end

always @(posedge clk_i) begin
    reg5 <= di_vl;
    reg4 <= di_dt;    
    
    if (reg6_f) begin
        do_dt <= bmem[reg2[STAGES - 1 : 0]] << (NWIDTH / 2 - mmp[reg3] - 1);
        blk_exp_o <= (NWIDTH / 2 - mmp[reg3] - 1);
    end

    if (reg5)         bmem[reg1[STAGES - 1 : 0]]   <= reg4;
end

always @(posedge clk_i) begin
    if (reset_i) begin
        reg6_f <= '0;
        do_vl <= '0;
    end else begin
        reg6_f <= reg6;
        do_vl <= reg6_f;        
    end
end

function xyz;
    input [NWIDTH / 2 - 1 : 0] data;
    input [$clog2(NWIDTH / 2) - 1 : 0] MSB_pos;
begin
    if (data[NWIDTH / 2 - 1]) begin
        xyz = !data[MSB_pos];
    end else begin
        xyz = data[MSB_pos];
    end
end
endfunction

reg [NWIDTH - 1 : 0] used_bits;
reg end_loop;
integer val1 = 0;

always @(posedge clk_i) begin
    if (reset_i) begin
        mmp[0] <= '0;
        mmp[1] <= '0;
    end else begin
        if (di_vl) begin
            end_loop = 0;
            for (integer i = NWIDTH / 2 - 2; i > 0; i = i - 1) begin
                if ((xyz(di_dt[NWIDTH - 1 : NWIDTH / 2], i) || xyz(di_dt[NWIDTH / 2 - 1 : 0], i)) == 0) begin
                    if (!end_loop) begin
                        val1 = i;
                    end
                end else begin
                    end_loop = 1;
                end
            end
            if ((reg1 == 2 ** STAGES) || (reg1 == 0)) begin
                mmp[reg1[STAGES]] <= val1;
            end else begin
                mmp[reg1[STAGES]] <= mmp[reg1[STAGES]] > val1 ? mmp[reg1[STAGES]] : val1;
            end
        end
    end
end

endmodule