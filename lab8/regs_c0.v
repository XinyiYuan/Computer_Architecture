`include "mycpu.h"

module regs_c0(
    input  clk,
    input  rst,
    input  wb_valid,
    input  op_mtc0,
    input  op_mfc0,
    input  op_eret,
    input  op_sysc,
    input  wb_ex, // if ex
    input  [ 4:0] wb_rd,
    input  [ 2:0] wb_sel,
    input  [31:0] c0_wdata,
    output [31:0] c0_rdata,
    input  wb_bd,//if br delay slot
    input  [ 5:0] ext_int_in,
    input  [ 4:0] wb_excode,
    input  [31:0] wb_pc,
    // not used yet (lab9)
    input  [31:0] wb_badvaddr // badvaddr
);

// pre
wire [7:0] c0_addr;
assign c0_addr = {wb_sel, wb_rd}; // sel+rd decide cpr's address

/*
 * Status
 */
// BEV: R, always 1
wire c0_status_bev;
assign c0_status_bev = 1'b1;

// IM(7~0): R&W
wire mtc0_we;
assign mtc0_we = wb_valid && op_mtc0 && !wb_ex;
reg [7:0] c0_status_im;
always @(posedge clk) begin
    if (rst) begin
        c0_status_im <= 8'b0;
    end
    else if (mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_im <= c0_wdata[15:8];
    end
end

// EXL: R&W
reg c0_status_exl;
wire eret_flush;
assign eret_flush = op_eret; //?
always @(posedge clk) begin
    if (rst) begin
        c0_status_exl <= 1'b0;
    end
    else if (wb_ex) begin
        c0_status_exl <= 1'b1;
    end
    else if (eret_flush) begin
        c0_status_exl <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_exl <= c0_wdata[1];
    end
end

// IE
reg c0_status_ie;
always@(posedge clk) begin
    if (rst) begin
        c0_status_ie <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_ie <= c0_wdata[0];
    end
end

wire [31:0] c0_status;
assign c0_status = {9'b0,
                    c0_status_bev,
                    6'b0,
                    c0_status_im,
                    6'b0,
                    c0_status_exl,
                    c0_status_ie};

/*
 * Cause
 */
// BD
reg c0_cause_bd;
always@(posedge clk) begin
    if (rst) begin
        c0_cause_bd <= 1'b0;
    end
    else if (mtc0_we && !c0_status_exl ) begin
        c0_cause_bd <= wb_bd;
    end
end

// TI
reg c0_cause_ti;
wire count_eq_compare; //! PIT
assign count_eq_compare = 1'b0;//! PIT
always@(posedge clk) begin
    if (rst) begin
        c0_cause_ti <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_CAUSE) begin
        c0_cause_ti <= 1'b0;
    end
    else if (count_eq_compare) begin //! PIT
        c0_cause_ti <= 1'b1;
    end
end

// IP(7~0)
reg [ 7:0] c0_cause_ip;
//   IP7~2
always @(posedge clk) begin
    if (rst) begin
        c0_cause_ip[ 7:2] <= 6'b0;
    end
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end
//   IP1~0
always @(posedge clk) begin
    if (rst) begin
        c0_cause_ip[1:0] <= 2'b0;
    end
    else begin
        c0_cause_ip[1:0] <= c0_wdata[9:8];
    end
end
// Excode
reg [ 4:0] c0_cause_excode;
always @(posedge clk) begin
    if (rst) begin
        c0_cause_excode <= 5'b0;
    end
    else if (wb_ex) begin
        c0_cause_excode <= wb_excode;
    end
end

wire [31:0] c0_cause;
assign c0_cause = {c0_cause_bd,
                   c0_cause_ti,
                   14'b0,
                   c0_cause_ip,
                   1'b0,
                   c0_cause_excode,
                   2'b0};


/*
 * EPC
 */
reg [31:0] c0_epc;
always @(posedge clk) begin
    if (rst) begin
        c0_epc <= 32'b0;
    end
    else if (wb_ex && !c0_status_exl) begin
        c0_epc <= wb_bd ? wb_pc - 3'h4 : wb_pc;
    end
    else if (mtc0_we && c0_addr == `CR_EPC) begin
        c0_epc <= c0_wdata;
    end
end


/* read selection & assignment: begin*/
wire read_c0_status;
wire read_c0_cause;
wire read_c0_epc;
assign read_c0_status = (c0_addr ==`CR_STATUS);
assign read_c0_cause  = (c0_addr ==`CR_CAUSE );
assign read_c0_epc    = (c0_addr ==`CR_EPC   ) || eret_flush;
assign c0_rdata = {32{read_c0_status}} & c0_status
                | {32{read_c0_cause}}  & c0_cause
                | {32{read_c0_epc}}    & c0_epc;

/* read selection & assignment: end*/

/* ------------------------lab 9 below------------------ */

/*
 * BadVAddr
 */

reg [31:0] c0_badvaddr;
always @(posedge clk) begin
    if (rst) begin
        c0_badvaddr <= 32'b0;
    end
    else if (wb_ex && wb_excode == `EX_ADEL) begin
        c0_badvaddr <= wb_badvaddr;
    end
end


/*
 * Count
 */

reg        tick;
reg [31:0] c0_count;
always @(posedge clk) begin
    if (rst) begin
        tick <= 1'b0;
    end
    else begin
        tick <= ~tick;
    end

    if (rst) begin
        c0_count <= 32'b0;
    end
    else if (mtc0_we && c0_addr == `CR_COUNT) begin
        c0_count <= c0_wdata;
    end
    else if (tick) begin
        c0_count <= c0_count + 1'b1;
    end
end

/*
 * Compare
 */
reg [31:0] c0_compare;
always @(posedge clk) begin
    if (rst) begin
        c0_compare <= 32'b0;
    end
    else if (mtc0_we && `CR_COMPARE) begin
        c0_compare <= c0_wdata;
    end
end

endmodule