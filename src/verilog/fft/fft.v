// -------------------------------------------------------------------------------
// private code of benjamin menkuec, not for commercial use
// no redistribution without consent of owner
// copyright benjamin menkuec
// -------------------------------------------------------------------------------


`timescale 1ns / 1ns

module fft #(
    parameter NFFT = 16,
    parameter FORMAT = 1,
    parameter RNDMODE = 0,
    parameter DATA_WIDTH = 16,
    parameter TWDL_WIDTH = 16,
    parameter XSERIES = "NEW",
    parameter USE_MLT = 0,
    parameter SHIFTED = 0,               // 0: start with positive frequencies, 1: start with most negative frequency
    parameter DBS = 1,                   // Dynamic Block Scaling

    localparam DATA_WIDTH_OUT = DATA_WIDTH+FORMAT*NFFT
)
(
    input                                       rst,
    input                                       clk,

    // ---- Input data ----
    input   [DATA_WIDTH-1 : 0]                  di_re,
    input   [DATA_WIDTH-1 : 0]                  di_im,
    input                                       di_en,
    // ---- Output data ----
    output   reg     [DATA_WIDTH_OUT - 1 : 0]   do_re,
    output   reg     [DATA_WIDTH_OUT - 1 : 0]   do_im,
    output   reg                                do_vl,
    output   reg                                sync,
    output   reg     [$clog2(DATA_WIDTH_OUT / 2) - 1 : 0]   blk_exp_o
);

// ---------------- Input data ----------------
wire [2*DATA_WIDTH-1 : 0]                       di_dt;
wire [2*DATA_WIDTH-1 : 0]                       da_dt;
wire [2*DATA_WIDTH-1 : 0]                       db_dt;

// ---------------- Forward FFT ----------------
wire [DATA_WIDTH-1 : 0]                         di_re0;
wire [DATA_WIDTH-1 : 0]                         di_im0;
wire [DATA_WIDTH-1 : 0]                         di_re1;
wire [DATA_WIDTH-1 : 0]                         di_im1;

wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             do_re0;
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             do_im0;
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             do_re1;
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             do_im1;

wire                                            di_ena;
wire                                            do_val;

// ---------------- Shuffle data ----------------
wire [2*(FORMAT*NFFT+DATA_WIDTH)-1 : 0]         dt_int0;
wire [2*(FORMAT*NFFT+DATA_WIDTH)-1 : 0]         dt_int1;
wire                                            dt_en01;

wire [2*(FORMAT*NFFT+DATA_WIDTH)-1 : 0]         qx_dt;

// ---------------- Output data ----------------
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             dx_re;
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             dx_im;
wire                                            dx_vl;

wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             dr_re;
wire [FORMAT*NFFT+DATA_WIDTH-1 : 0]             dr_im;
wire                                            dr_en;

reg [NFFT - 1 : 0]                              sync_cnt;

assign di_dt = {di_im, di_re};

// -------------------- INPUT BUFFER --------------------
inbuf_half_path #(
    .ADDR(NFFT),
    .DATA(2*DATA_WIDTH)
)
xIN_BUF(
    .clk(clk),
    .rst(rst),

    .di_dt(di_dt),
    .di_en(di_en),

    .da_dt(da_dt),
    .db_dt(db_dt),
    .ab_vl(di_ena)
);

assign di_re0 = da_dt[1*DATA_WIDTH-1 : 0*DATA_WIDTH];
assign di_im0 = da_dt[2*DATA_WIDTH-1 : 1*DATA_WIDTH];
assign di_re1 = db_dt[1*DATA_WIDTH-1 : 0*DATA_WIDTH];
assign di_im1 = db_dt[2*DATA_WIDTH-1 : 1*DATA_WIDTH];

// ------------------ FFTK_N (FORWARD FFT) ------------------
int_fftNk #(
    .NFFT(NFFT),
    .FORMAT(FORMAT),
    .RNDMODE(RNDMODE),
    .DATA_WIDTH(DATA_WIDTH),
    .TWDL_WIDTH(TWDL_WIDTH),
    .XSER(XSERIES),
    .USE_MLT(USE_MLT)
)
xFFT(
    .DI_RE0(di_re0),
    .DI_IM0(di_im0),
    .DI_RE1(di_re1),
    .DI_IM1(di_im1),
    .DI_ENA(di_ena),

    .USE_FLY(1),

    .DO_RE0(do_re0),
    .DO_IM0(do_im0),
    .DO_RE1(do_re1),
    .DO_IM1(do_im1),
    .DO_VAL(do_val),

    .rst(rst),
    .clk(clk)
);

// -------------------- OUTPUT BUFFER --------------------
assign dt_int0 = {do_im0, do_re0};
assign dt_int1 = {do_im1, do_re1};
assign dt_en01 = do_val;

outbuf_half_path #(
    .ADDR(NFFT),
    .DW(2*(FORMAT*NFFT+DATA_WIDTH))
)
xOUT_BUF(
    .clk(clk),
    .rst(rst),

    .da_dt(dt_int0),
    .db_dt(dt_int1),
    .ab_vl(dt_en01),

    .do_dt(qx_dt),
    .do_vl(dx_vl)
);

assign dx_re = qx_dt[1*(FORMAT*NFFT+DATA_WIDTH)-1 : 0*(FORMAT*NFFT+DATA_WIDTH)];
assign dx_im = qx_dt[2*(FORMAT*NFFT+DATA_WIDTH)-1 : 1*(FORMAT*NFFT+DATA_WIDTH)];

// -------------------- BIT REVERSE ORDER --------------------
int_bitrev_order #(
    .PAIR(1),
    .STAGES(NFFT),
    .NWIDTH(FORMAT*NFFT+DATA_WIDTH),
    .SHIFTED(SHIFTED)
)
xBR_RE (
    .clk(clk),
    .rst(rst),

    .di_dt(dx_re),
    .di_en(dx_vl),
    .do_dt(dr_re),
    .do_vl(dr_en)
);

int_bitrev_order #(
    .PAIR(1),
    .STAGES(NFFT),
    .NWIDTH(FORMAT*NFFT+DATA_WIDTH),
    .SHIFTED(SHIFTED)
)
xBR_IM (
    .clk(clk),
    .rst(rst),

    .di_dt(dx_im),
    .di_en(dx_vl),
    .do_dt(dr_im),
    .do_vl()
);

if (DBS) begin
    localparam DATA_WIDTH_OUT = FORMAT*NFFT+DATA_WIDTH;
    wire [2 * DATA_WIDTH_OUT - 1 : 0]   dbs_data;
    wire                            dbs_valid;
    wire [$clog2(DATA_WIDTH_OUT / 2) - 1 : 0] blk_exp;

    dynamic_block_scaling #(
        .NWIDTH(2 * DATA_WIDTH_OUT),
        .STAGES(NFFT)
    )
    dynamic_block_scaling_i(
        .clk_i(clk),
        .reset_i(rst),

        .di_dt({dr_im, dr_re}),
        .di_vl(dr_en),

        .do_dt(dbs_data),
        .do_vl(dbs_valid),
        .blk_exp_o(blk_exp)
    );
    // ------------------ xDATA OUTPUT --------------------
    always @(posedge clk) begin
        if (rst) begin
            do_re <= '0;
            do_im <= '0;
            do_vl <= '0;
            blk_exp_o <= '0;
        end else begin
            do_re <= dbs_data[DATA_WIDTH_OUT - 1 : 0];
            do_im <= dbs_data[DATA_WIDTH_OUT * 2 - 1 : DATA_WIDTH_OUT];
            blk_exp_o <= blk_exp;
            do_vl <= dbs_valid;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sync <= '0;
            sync_cnt <= '0;
        end else begin
            if (dr_en) begin
                sync_cnt <= sync_cnt + 1;
            end
            sync <= dr_en && (sync_cnt == 2**NFFT - 1);
        end
    end    

end else begin
    assign blk_exp_o = '0;
    // ------------------ xDATA OUTPUT --------------------
    always @(posedge clk) begin
        if (rst) begin
            do_re <= '0;
            do_im <= '0;
            do_vl <= '0;
        end else begin
            do_re <= dr_re;
            do_im <= dr_im;
            do_vl <= dr_en;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sync <= '0;
            sync_cnt <= '0;
        end else begin
            if (dr_en) begin
                sync_cnt <= sync_cnt + 1;
            end
            sync <= dr_en && (sync_cnt == 2**NFFT - 1);
        end
    end
end

endmodule
