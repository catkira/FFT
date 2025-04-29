// -------------------------------------------------------------------------------
// private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------


module outbuf_half_path #(
    parameter   ADDR = 10,
    parameter   DW = 32
)
(
    input                           clk,
    input                           rst,

    input    [DW-1 : 0]             da_dt,  // even data
    input    [DW-1 : 0]             db_dt,  // odd data
    input                           ab_vl,

    output  reg [DW-1 : 0]          do_dt,
    output  reg                     do_vl
);

reg [ADDR-1 : 0]        cnt;
reg [ADDR-2 : 0]        addr_wr;

reg [ADDR-1 : 0]        cnt_rd;
reg                     ena_rd;
reg                     ena_rd_f;

reg                     ab_vl_f;

reg [ADDR-2 : 0]        ram_rdad;
reg [DW-1 : 0]          ram_doa;
reg [DW-1 : 0]          da_dt_f;

reg [DW-1 : 0]          mem  [(2**(ADDR-1))-1 : 0];

always @(posedge clk) begin
    if (rst) begin
        cnt <= 1'b1;
        addr_wr <= 0;
        
        cnt_rd <= 1'b1;
        ena_rd <= 0;

        ram_rdad <= 0;
    end else begin
        if (ab_vl) begin
            cnt <= cnt[ADDR-1] ? 1'b1 : cnt + 1;
        end

        if (ab_vl)  addr_wr <= addr_wr + 1;

        if (ena_rd) begin
            if (cnt_rd[ADDR-1]) begin
                cnt_rd <= 1'b1;
                ram_rdad <= 0;
            end else begin
                cnt_rd <= cnt_rd + 1;
                ram_rdad <= ram_rdad + 1;
            end
        end

        if (cnt[ADDR-1]) begin
            if (ab_vl)  ena_rd <= 1'b1;
        end else if (cnt_rd[ADDR-1]) begin
            ena_rd <= 0;
        end
    end
end

always @(posedge clk) begin
    ena_rd_f <= ena_rd;
    da_dt_f <= da_dt;
    ab_vl_f <= ab_vl;    

    if (!ena_rd_f) begin        // forward input a directly to output
        do_dt <= da_dt_f;
        do_vl <= ab_vl_f;
    end else begin              // output stored input b from buffer
        do_dt <= ram_doa;
        do_vl <= ena_rd_f;
    end
end

// ---------------- Mapping dual-port RAM --------------------
always @(posedge clk) begin
    if (ena_rd)  ram_doa <= mem[ram_rdad];
    if (ab_vl)   mem[addr_wr] <= db_dt;
end

endmodule