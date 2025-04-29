// -------------------------------------------------------------------------------
// private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------


module inbuf_half_path #(
    parameter       ADDR = 10,
    parameter       DATA = 32
)
(
    input                           clk,
    input                           rst,

    input           [DATA-1 : 0]    di_dt,
    input                           di_en,

    output  reg     [DATA-1 : 0]    da_dt,
    output  reg     [DATA-1 : 0]    db_dt,
    output  reg                     ab_vl
);

reg     [ADDR-0 : 0]                cnt;
reg     [ADDR-1 : 0]                addr_wr;

reg     [ADDR-1 : 0]                cnt_rd;
reg                                 ena_rd;

reg                                 ram_wea0;
reg                                 ram_wea1;
reg     [ADDR-2 : 0]                ram_wrad;
reg     [ADDR-2 : 0]                ram_rdad;
reg     [DATA-1 : 0]                ram_dia;
reg     [DATA-1 : 0]                ram_doa;
reg     [DATA-1 : 0]                ram_dob;
reg                                 ram_vl;

reg     [DATA-1 : 0]                mem0  [(2**(ADDR-1))-1 : 0];
reg     [DATA-1 : 0]                mem1  [(2**(ADDR-1))-1 : 0];

always @(posedge clk) begin
    if (rst) begin
        cnt <= 1'b1;
        addr_wr <= 0;
        cnt_rd <= 1'b1;
        ena_rd <= 0;
        ram_wea0 <= 0;
        ram_wea1 <= 0;
        ram_rdad <= 0;
    end else begin
        ram_wea0 <= di_en & !addr_wr[ADDR-1];
        ram_wea1 <= di_en &  addr_wr[ADDR-1];

        if (di_en) begin
            cnt <= cnt[ADDR-0] ? 1'b1 : cnt + 1;
            addr_wr <= addr_wr + 1;            
        end

        if (ena_rd) begin
            cnt_rd <= cnt_rd[ADDR-1] ? 1'b1 : cnt_rd + 1;
            ram_rdad <= cnt_rd[ADDR-1] ? 0 : ram_rdad + 1;
        end

        if (cnt[ADDR-0]) begin
            ena_rd <= di_en ? 1'b1 : ena_rd;
        end else if (cnt_rd[ADDR-1]) begin
            ena_rd <= 0;
        end
    end
end

always @(posedge clk) begin
    ram_wrad <= addr_wr[ADDR-2 : 0];
    ram_dia  <= di_dt;
    ram_vl   <= ena_rd;
end

// ---- Port A write ----
always @(posedge clk) begin
    if (ena_rd)         ram_doa        <= mem0[ram_rdad];
    if (ram_wea0)       mem0[ram_wrad] <= ram_dia;
end

// ---- Port B write ----
always @(posedge clk) begin
    if (ena_rd)         ram_dob       <= mem1[ram_rdad];
    if (ram_wea1)       mem1[ram_wrad] <= ram_dia;
end

always @(posedge clk) begin
    da_dt <= ram_doa;
    db_dt <= ram_dob;
    ab_vl <= ram_vl;
end

endmodule